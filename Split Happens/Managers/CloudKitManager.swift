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
            case .serverRecordChanged:
                print("⚠️ Server record changed error - should be handled by conflict resolution")
                return .unknown(error)
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
        let groupID = record.recordID.recordName
        
        // First, fetch and delete all expenses for this group
        do {
            let expenses = try await fetchExpenses(for: record)
            for expenseRecord in expenses {
                try await performWithRetry {
                    try await self.database.deleteRecord(withID: expenseRecord.recordID)
                }
            }
            print("✅ Deleted \(expenses.count) expenses for group \(groupID)")
        } catch {
            print("⚠️ Failed to delete expenses for group: \(error)")
        }
        
        // Delete from CloudKit
        try await performWithRetry {
            try await self.database.deleteRecord(withID: record.recordID)
        }
        print("✅ Deleted group \(groupID) from CloudKit")
        
        // Delete from local storage
        await MainActor.run {
            let offlineManager = OfflineStorageManager.shared
            var localGroups = offlineManager.loadGroups()
            localGroups.removeAll { $0.id == groupID }
            offlineManager.saveGroups(localGroups)
            
            // Also delete all associated expenses
            var localExpenses = offlineManager.loadExpenses()
            localExpenses.removeAll { $0.groupReference == groupID }
            offlineManager.saveExpenses(localExpenses)
            
            // Update sync status
            offlineManager.updateSyncStatus(for: groupID, status: .synced)
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
            // Create proper reference to match how expenses are saved
            let groupReference = CKRecord.Reference(recordID: group.recordID, action: .none)
            let predicate = NSPredicate(format: "groupReference == %@", groupReference)
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
        
        // Ensure finite values using safeValue
        validatedGroup.totalSpent = validatedGroup.totalSpent.safeValue
        
        guard validateGroup(validatedGroup) else {
            print("❌ Group validation failed after fixes")
            throw CloudKitManagerError.invalidData
        }
        
        // Check if group already exists
        let recordID = CKRecord.ID(recordName: group.id)
        
        do {
            // Try to fetch existing record WITHOUT retry logic since "not found" is a valid response
            let existingRecord = try await self.database.record(for: recordID)
            
            // Update existing record
            existingRecord["name"] = validatedGroup.name
            existingRecord["participants"] = validatedGroup.participants
            existingRecord["participantIDs"] = validatedGroup.participantIDs
            existingRecord["totalSpent"] = validatedGroup.totalSpent.safeValue
            existingRecord["lastActivity"] = validatedGroup.lastActivity
            existingRecord["isActive"] = validatedGroup.isActive
            existingRecord["currency"] = validatedGroup.currency
            
            let savedRecord = try await performWithRetry {
                try await self.database.save(existingRecord)
            }
            
            guard let updatedGroup = Group(from: savedRecord) else {
                throw CloudKitManagerError.invalidData
            }
            
            print("✅ Updated existing group: \(updatedGroup.name)")
            return updatedGroup
            
        } catch {
            // Check if it's a "record not found" error - this is expected for new groups
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                print("📝 Record doesn't exist, creating new group: \(validatedGroup.name)")
                let newRecord = validatedGroup.toCKRecord()
                
                let savedRecord = try await performWithRetry {
                    try await self.database.save(newRecord)
                }
                
                guard let newGroup = Group(from: savedRecord) else {
                    throw CloudKitManagerError.invalidData
                }
                
                print("✅ Created new group: \(newGroup.name)")
                return newGroup
            } else {
                // For other errors, throw them
                print("❌ Unexpected error while checking/saving group: \(error)")
                throw CloudKitManagerError.unknown(error)
            }
        }
    }
    
    private func saveGroupWithConflictResolution(_ record: CKRecord) async throws -> CKRecord {
        do {
            return try await self.database.save(record)
        } catch {
            if let ckError = error as? CKError {
                switch ckError.code {
                case .serverRecordChanged:
                    print("⚠️ Server record changed, attempting to resolve conflict")
                    return try await resolveGroupConflict(record, serverError: ckError)
                case .unknownItem:
                    // Record doesn't exist, safe to create
                    record.setValue(Date(), forKey: "lastActivity")
                    return try await self.database.save(record)
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    private func resolveGroupConflict(_ record: CKRecord, serverError: CKError) async throws -> CKRecord {
        // Get the server record from the error
        guard let serverRecord = serverError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            // If we can't get the server record, fetch it manually
            let fetchedRecord = try await database.record(for: record.recordID)
            return try await mergeGroupRecords(local: record, server: fetchedRecord)
        }
        
        return try await mergeGroupRecords(local: record, server: serverRecord)
    }
    
    private func mergeGroupRecords(local: CKRecord, server: CKRecord) async throws -> CKRecord {
        // Merge strategy: keep the most recent data
        let localLastActivity = local["lastActivity"] as? Date ?? Date.distantPast
        let serverLastActivity = server["lastActivity"] as? Date ?? Date.distantPast
        
        let mergedRecord = server // Start with server record
        
        // If local is more recent, update server record with local changes
        if localLastActivity > serverLastActivity {
            print("🔄 Local record is newer, updating server record")
            mergedRecord["name"] = local["name"]
            mergedRecord["participants"] = local["participants"]
            mergedRecord["participantIDs"] = local["participantIDs"]
            mergedRecord["currency"] = local["currency"]
            mergedRecord["isActive"] = local["isActive"]
        }
        
        // Always merge totalSpent (combine if different)
        let localTotal = local["totalSpent"] as? Double ?? 0
        let serverTotal = server["totalSpent"] as? Double ?? 0
        
        if localTotal != serverTotal {
            // Keep the higher total (assuming expenses were added)
            mergedRecord["totalSpent"] = max(localTotal, serverTotal)
        }
        
        mergedRecord["lastActivity"] = max(localLastActivity, serverLastActivity)
        
        return try await self.database.save(mergedRecord)
    }
    
    private func checkForDuplicateGroup(_ group: Group) async throws -> Group? {
        // Search for groups with same name and similar participants
        let predicate = NSPredicate(format: "name == %@ AND isActive == %@", group.name, NSNumber(value: true))
        let query = CKQuery(recordType: "Group", predicate: predicate)
        
        do {
            let (matchResults, _) = try await database.records(matching: query)
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let existingGroup = Group(from: record) {
                        // Check if participants overlap significantly (75% or more)
                        let overlap = Set(group.participants).intersection(Set(existingGroup.participants))
                        let overlapPercentage = Double(overlap.count) / Double(max(group.participants.count, existingGroup.participants.count))
                        
                        if overlapPercentage >= 0.75 {
                            return existingGroup
                        }
                    }
                case .failure:
                    continue
                }
            }
        } catch {
            print("⚠️ Error checking for duplicates: \(error)")
            // Continue with save if duplicate check fails
        }
        
        return nil
    }
    
    private func updateExistingGroup(_ existingGroup: Group, with newGroup: Group) async throws -> Group {
        var mergedGroup = existingGroup
        
        // Merge participants (add any new ones)
        for participant in newGroup.participants {
            if !mergedGroup.participants.contains(participant) {
                mergedGroup.addParticipant(participant)
            }
        }
        
        // Update other fields if the new group has more recent data
        mergedGroup.lastActivity = max(existingGroup.lastActivity, newGroup.lastActivity)
        
        // Save the merged group
        let record = mergedGroup.toCKRecord()
        let savedRecord = try await self.database.save(record)
        
        guard let updatedGroup = Group(from: savedRecord) else {
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
        
        // Check for duplicate expenses
        if let existingExpense = try await checkForDuplicateExpense(expense) {
            print("⚠️ Found duplicate expense, returning existing: \(existingExpense.description)")
            return existingExpense
        }
        
        let record = expense.toCKRecord()
        let savedRecord = try await performWithRetry {
            try await self.saveExpenseWithConflictResolution(record)
        }
        guard let updatedExpense = Expense(from: savedRecord) else {
            print("Failed to convert saved record back to Expense")
            throw CloudKitManagerError.invalidData
        }
        return updatedExpense
    }
    
    private func saveExpenseWithConflictResolution(_ record: CKRecord) async throws -> CKRecord {
        do {
            return try await self.database.save(record)
        } catch {
            if let ckError = error as? CKError {
                switch ckError.code {
                case .serverRecordChanged:
                    print("⚠️ Server expense record changed, attempting to resolve conflict")
                    return try await resolveExpenseConflict(record, serverError: ckError)
                case .unknownItem:
                    // Record doesn't exist, safe to create
                    record.setValue(Date(), forKey: "date")
                    return try await self.database.save(record)
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    private func resolveExpenseConflict(_ record: CKRecord, serverError: CKError) async throws -> CKRecord {
        // For expenses, prefer the server record to avoid duplicates
        guard let serverRecord = serverError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            let fetchedRecord = try await database.record(for: record.recordID)
            return fetchedRecord
        }
        
        return serverRecord
    }
    
    private func checkForDuplicateExpense(_ expense: Expense) async throws -> Expense? {
        // Search for expenses with same description, amount, and group within a small time window
        let groupReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: expense.groupReference), action: .none)
        let predicate = NSPredicate(format: "groupReference == %@ AND description == %@ AND totalAmount == %@", 
                                  groupReference, expense.description, NSNumber(value: expense.totalAmount))
        let query = CKQuery(recordType: "Expense", predicate: predicate)
        
        do {
            let (matchResults, _) = try await database.records(matching: query)
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let existingExpense = Expense(from: record) {
                        // Check if the expense was created within the last 5 minutes (likely duplicate)
                        let timeDifference = abs(existingExpense.date.timeIntervalSince(expense.date))
                        if timeDifference < 300 { // 5 minutes
                            return existingExpense
                        }
                    }
                case .failure:
                    continue
                }
            }
        } catch {
            print("⚠️ Error checking for duplicate expenses: \(error)")
            // Continue with save if duplicate check fails
        }
        
        return nil
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
    
    func fetchGroup(by groupID: String) async throws -> Group? {
        let recordID = CKRecord.ID(recordName: groupID)
        
        do {
            let record = try await database.record(for: recordID)
            return Group(from: record)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return nil // Group not found
            }
            throw error
        }
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