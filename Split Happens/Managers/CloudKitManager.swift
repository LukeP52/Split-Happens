//
//  CloudKitManager.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import CloudKit
import SwiftUI

enum CloudKitManagerError: LocalizedError {
    case noiCloudAccount
    case networkUnavailable
    case quotaExceeded
    case permissionFailure
    case recordNotFound
    case invalidData
    case retryLimitExceeded
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noiCloudAccount:
            return "No iCloud account available. Please sign in to iCloud in Settings."
        case .networkUnavailable:
            return "Network connection unavailable. Please check your internet connection."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Please free up space."
        case .permissionFailure:
            return "Permission denied. Please check iCloud settings for this app."
        case .recordNotFound:
            return "Record not found."
        case .invalidData:
            return "Invalid data format."
        case .retryLimitExceeded:
            return "Operation failed after multiple retries."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer(identifier: "iCloud.SplitHappens")
    private let database: CKDatabase
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    private let operationTimeout: TimeInterval = 30.0 // 30 second timeout for CloudKit operations
    
    // Circuit breaker to prevent excessive retries
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 5
    private var circuitBreakerResetTime: Date?
    private let circuitBreakerTimeout: TimeInterval = 300.0 // 5 minutes
    
    @Published var isSignedInToiCloud = false
    @Published var error: String?
    @Published var isLoading = false
    
    init() {
        self.database = container.privateCloudDatabase
        Task {
            await checkiCloudAvailability()
            await setupSubscriptions()
        }
    }
    
    // MARK: - iCloud Status
    
    private func checkiCloudAvailability() async {
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.isSignedInToiCloud = status == .available
                if status != .available {
                    self.error = self.getAccountStatusError(status).localizedDescription
                }
            }
        } catch {
            await MainActor.run {
                self.error = CloudKitManagerError.unknown(error).localizedDescription
                self.isSignedInToiCloud = false
            }
        }
    }
    
    private func getAccountStatusError(_ status: CKAccountStatus) -> CloudKitManagerError {
        switch status {
        case .noAccount:
            return .noiCloudAccount
        case .restricted:
            return .permissionFailure
        case .couldNotDetermine:
            return .networkUnavailable
        case .available:
            return .unknown(NSError(domain: "CloudKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown status error"]))
        case .temporarilyUnavailable:
            return .networkUnavailable
        @unknown default:
            return .unknown(NSError(domain: "CloudKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown account status"]))
        }
    }
    
    // MARK: - Error Handling & Retry Logic
    
    private func withTimeout<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        let task = Task {
            try await operation()
        }
        
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(self.operationTimeout * 1_000_000_000))
            task.cancel()
            throw CloudKitManagerError.unknown(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(self.operationTimeout) seconds"]))
        }
        
        do {
            let result = try await task.value
            timeoutTask.cancel()
            return result
        } catch {
            timeoutTask.cancel()
            if task.isCancelled {
                throw CloudKitManagerError.unknown(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(self.operationTimeout) seconds"]))
            }
            throw error
        }
    }
    
    private func performWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        print("🔄 Starting performWithRetry")
        
        // Check circuit breaker
        if let resetTime = circuitBreakerResetTime {
            if Date() < resetTime {
                print("❌ Circuit breaker is active")
                throw CloudKitManagerError.unknown(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Circuit breaker active - too many consecutive failures"]))
            } else {
                // Reset circuit breaker
                consecutiveFailures = 0
                circuitBreakerResetTime = nil
            }
        }
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 Attempt \(attempt) of \(maxRetries)")
                let result = try await withTimeout(operation)
                // Reset failure count on success
                consecutiveFailures = 0
                circuitBreakerResetTime = nil
                print("✅ Operation succeeded on attempt \(attempt)")
                return result
            } catch {
                lastError = error
                print("❌ Attempt \(attempt) failed: \(error)")
                let cloudKitError = mapToCloudKitError(error)
                
                // Don't retry certain errors
                if !shouldRetry(cloudKitError) {
                    print("❌ Error is not retryable")
                    throw cloudKitError
                }
                
                // Wait before retry (exponential backoff)
                if attempt < maxRetries {
                    let delay = retryDelay * pow(2.0, Double(attempt - 1))
                    print("⏳ Waiting \(delay) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        print("❌ All retries exhausted")
        
        // All retries failed - activate circuit breaker if we've had too many consecutive failures
        consecutiveFailures += 1
        if consecutiveFailures >= maxConsecutiveFailures {
            circuitBreakerResetTime = Date().addingTimeInterval(circuitBreakerTimeout)
            print("⚠️ Circuit breaker activated after \(consecutiveFailures) consecutive failures. Will reset at \(circuitBreakerResetTime!)")
        }
        
        throw CloudKitManagerError.retryLimitExceeded
    }
    
    private func shouldRetry(_ error: CloudKitManagerError) -> Bool {
        switch error {
        case .networkUnavailable, .unknown:
            return true
        case .noiCloudAccount, .quotaExceeded, .permissionFailure, .recordNotFound, .invalidData, .retryLimitExceeded:
            return false
        }
    }
    
    private func mapToCloudKitError(_ error: Error) -> CloudKitManagerError {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return .noiCloudAccount
            case .networkUnavailable, .networkFailure:
                return .networkUnavailable
            case .quotaExceeded:
                return .quotaExceeded
            case .permissionFailure:
                return .permissionFailure
            case .unknownItem:
                return .recordNotFound
            case .invalidArguments, .incompatibleVersion:
                return .invalidData
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }
    
    // MARK: - Group Operations
    
    func createGroup(name: String, participants: [String]) async throws -> CKRecord {
        return try await performWithRetry {
            let record = CKRecord(recordType: "Group")
            record["name"] = name
            record["participants"] = participants
            record["participantIDs"] = participants.map { _ in UUID().uuidString }
            record["totalSpent"] = 0.0
            record["lastActivity"] = Date()
            record["isActive"] = true
            record["currency"] = "USD"
            
            return try await self.database.save(record)
        }
    }
    
    func fetchGroups() async throws -> [CKRecord] {
        return try await performWithRetry {
            let predicate = NSPredicate(format: "isActive == %@", NSNumber(value: 1))
            let query = CKQuery(recordType: "Group", predicate: predicate)
            
            let result = try await self.database.records(matching: query)
            return result.matchResults.compactMap { try? $0.1.get() }
        }
    }
    
    func updateGroup(_ record: CKRecord) async throws -> CKRecord {
        return try await performWithRetry {
            record["lastActivity"] = Date()
            return try await self.database.save(record)
        }
    }
    
    func deleteGroup(_ record: CKRecord) async throws {
        try await performWithRetry {
            try await self.database.deleteRecord(withID: record.recordID)
        }
    }
    
    // MARK: - Expense Operations
    
    func addExpense(
        to group: CKRecord,
        amount: Double,
        paidBy: String,
        description: String,
        splitType: SplitType,
        participants: [String]
    ) async throws -> CKRecord {
        return try await performWithRetry {
            let expense = CKRecord(recordType: "Expense")
            
            // Create proper reference for the group
            let groupRef = CKRecord.Reference(recordID: group.recordID, action: .deleteSelf)
            expense["groupReference"] = groupRef
            
            expense["description"] = description
            expense["totalAmount"] = amount
            expense["paidBy"] = paidBy
            expense["paidByID"] = UUID().uuidString
            expense["splitType"] = splitType.rawValue
            expense["date"] = Date()
            expense["category"] = ExpenseCategory.other.rawValue
            expense["participantNames"] = participants
            
            let savedExpense = try await self.database.save(expense)
            
            // Update group's total spent
            if let currentTotal = group["totalSpent"] as? Double {
                group["totalSpent"] = currentTotal + amount
            } else {
                group["totalSpent"] = amount
            }
            group["lastActivity"] = Date()
            _ = try await self.database.save(group)
            
            return savedExpense
        }
    }
    
    func fetchExpenses(for group: CKRecord) async throws -> [CKRecord] {
        return try await performWithRetry {
            let predicate = NSPredicate(format: "groupReference == %@", group.recordID.recordName)
            let query = CKQuery(recordType: "Expense", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            let result = try await self.database.records(matching: query)
            return result.matchResults.compactMap { try? $0.1.get() }
        }
    }
    
    func deleteExpense(_ record: CKRecord) async throws {
        try await performWithRetry {
            try await self.database.deleteRecord(withID: record.recordID)
        }
    }
    
    // MARK: - Real-time Sync Subscriptions
    
    private func setupSubscriptions() async {
        guard isSignedInToiCloud else { return }
        
        do {
            try await createGroupSubscription()
            try await createExpenseSubscription()
        } catch {
            await MainActor.run {
                self.error = "Failed to setup real-time sync: \(error.localizedDescription)"
            }
        }
    }
    
    private func createGroupSubscription() async throws {
        let subscription = CKQuerySubscription(
            recordType: "Group",
            predicate: NSPredicate(value: true),
            subscriptionID: "group-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await performWithRetry {
            _ = try await self.database.save(subscription)
        }
    }
    
    private func createExpenseSubscription() async throws {
        let subscription = CKQuerySubscription(
            recordType: "Expense",
            predicate: NSPredicate(value: true),
            subscriptionID: "expense-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await performWithRetry {
            _ = try await self.database.save(subscription)
        }
    }
    
    // MARK: - Convenience Methods
    
    func saveGroup(_ group: Group) async throws -> Group {
        // Enhanced validation
        guard !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Group validation failed: empty name")
            throw CloudKitManagerError.invalidData
        }
        
        guard group.participants.count >= 1 else {
            print("❌ Group validation failed: no participants")
            throw CloudKitManagerError.invalidData
        }
        
        // Ensure participantIDs match participants count
        var validatedGroup = group
        if group.participantIDs.count != group.participants.count {
            print("⚠️ Fixing mismatched participantIDs count")
            validatedGroup.participantIDs = group.participants.map { _ in UUID().uuidString }
        }
        
        // Ensure finite values
        if !validatedGroup.totalSpent.isFinite {
            print("⚠️ Fixing non-finite totalSpent: \(validatedGroup.totalSpent)")
            validatedGroup.totalSpent = 0
        }
        
        guard validateGroup(validatedGroup) else {
            print("❌ Group validation failed after fixes")
            throw CloudKitManagerError.invalidData
        }
        
        let record = validatedGroup.toCKRecord()
        
        // Validate record before saving
        for key in ["name", "participants", "participantIDs", "totalSpent", "lastActivity", "isActive", "currency"] {
            if record[key] == nil {
                print("❌ Missing required field in CKRecord: \(key)")
                throw CloudKitManagerError.invalidData
            }
        }
        
        let savedRecord = try await performWithRetry {
            try await self.database.save(record)
        }
        
        guard let updatedGroup = Group(from: savedRecord) else {
            print("❌ Failed to convert saved record back to Group")
            throw CloudKitManagerError.invalidData
        }
        
        return updatedGroup
    }
    
    private func validateGroup(_ group: Group) -> Bool {
        guard !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Group validation failed: empty name")
            return false
        }
        guard group.participants.count >= 1 else {
            print("Group validation failed: no participants")
            return false
        }
        guard group.totalSpent.isFinite && group.totalSpent >= 0 else {
            print("Group validation failed: invalid totalSpent: \(group.totalSpent)")
            return false
        }
        return true
    }
    
    func saveExpense(_ expense: Expense) async throws -> Expense {
        // Validate expense data before saving
        guard validateExpense(expense) else {
            print("Expense validation failed: \(expense)")
            throw CloudKitManagerError.invalidData
        }
        
        let record = expense.toCKRecord()
        let savedRecord = try await performWithRetry {
            try await self.database.save(record)
        }
        guard let updatedExpense = Expense(from: savedRecord) else {
            print("Failed to convert saved record back to Expense")
            throw CloudKitManagerError.invalidData
        }
        return updatedExpense
    }
    
    private func validateExpense(_ expense: Expense) -> Bool {
        guard !expense.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Expense validation failed: empty description")
            return false
        }
        guard !expense.groupReference.isEmpty else {
            print("Expense validation failed: empty groupReference")
            return false
        }
        guard expense.totalAmount.isFinite && expense.totalAmount > 0 else {
            print("Expense validation failed: invalid totalAmount: \(expense.totalAmount)")
            return false
        }
        guard !expense.paidBy.isEmpty && !expense.paidByID.isEmpty else {
            print("Expense validation failed: empty paidBy or paidByID")
            return false
        }
        guard !expense.participantNames.isEmpty else {
            print("Expense validation failed: no participants")
            return false
        }
        return true
    }
    
    func fetchGroupsAsModels() async throws -> [Group] {
        print("🔍 DEBUG: Fetching groups using isActive predicate")
        
        do {
            // Query for active groups using the isActive field that's already queryable
            let predicate = NSPredicate(format: "isActive == %@", NSNumber(value: 1))
            let query = CKQuery(recordType: "Group", predicate: predicate)
            
            let (matchResults, _) = try await database.records(matching: query)
            
            print("✅ Query succeeded! Found \(matchResults.count) results")
            
            var groups: [Group] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let group = Group(from: record) {
                        groups.append(group)
                        print("✅ Created group: \(group.name)")
                    }
                case .failure(let error):
                    print("❌ Record error: \(error)")
                }
            }
            
            return groups
            
        } catch {
            print("❌ Query failed: \(error)")
            throw error
        }
    }
    
    func fetchExpensesAsModels(for groupID: String) async throws -> [Expense] {
        // We need the actual CKRecord.ID, not just the string
        let recordID = CKRecord.ID(recordName: groupID)
        let groupReference = CKRecord.Reference(recordID: recordID, action: .none)
        let predicate = NSPredicate(format: "groupReference == %@", groupReference)
        let query = CKQuery(recordType: "Expense", predicate: predicate)
        
        print("🔍 Fetching expenses with groupReference: \(recordID.recordName)")
        
        let records = try await performWithRetry {
            let result = try await self.database.records(matching: query)
            return result.matchResults.compactMap { try? $0.1.get() }
        }
        
        print("✅ Fetched \(records.count) expense records")
        
        let expenses = records.compactMap { Expense(from: $0) }
        return expenses.sorted { $0.date > $1.date }
    }
} 