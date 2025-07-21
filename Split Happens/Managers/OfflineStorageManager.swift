//
//  OfflineStorageManager.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import SwiftUI
import CloudKit

enum SyncStatus: String, CaseIterable, Codable {
    case synced = "synced"
    case syncing = "syncing"
    case offline = "offline"
    case conflict = "conflict"
    case failed = "failed"
    
    var icon: String {
        switch self {
        case .synced: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .offline: return "wifi.slash"
        case .conflict: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .synced: return .green
        case .syncing: return .blue
        case .offline: return .orange
        case .conflict: return .yellow
        case .failed: return .red
        }
    }
    
    var description: String {
        switch self {
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .offline: return "Offline"
        case .conflict: return "Conflict"
        case .failed: return "Sync Failed"
        }
    }
}

enum OperationType: String, Codable {
    case createGroup = "createGroup"
    case updateGroup = "updateGroup"
    case deleteGroup = "deleteGroup"
    case createExpense = "createExpense"
    case updateExpense = "updateExpense"
    case deleteExpense = "deleteExpense"
}

struct PendingOperation: Identifiable, Codable {
    let id: String
    let type: OperationType
    let timestamp: Date
    let data: Data
    var retryCount: Int = 0
    
    init(id: String = UUID().uuidString, type: OperationType, data: Data, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
    }
}

struct SyncableItem: Identifiable, Codable {
    let id: String
    var syncStatus: SyncStatus
    var lastModified: Date
    var isLocalOnly: Bool
    
    init(id: String, syncStatus: SyncStatus = .offline, lastModified: Date = Date(), isLocalOnly: Bool = false) {
        self.id = id
        self.syncStatus = syncStatus
        self.lastModified = lastModified
        self.isLocalOnly = isLocalOnly
    }
}

@MainActor
class OfflineStorageManager: ObservableObject {
    static let shared = OfflineStorageManager()
    
    @Published var syncStatus: SyncStatus = .offline
    @Published var pendingOperationsCount: Int = 0
    @Published var lastSyncTime: Date?
    @Published var isOnline: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Storage keys
    private let groupsKey = "offline_groups"
    private let expensesKey = "offline_expenses"
    private let pendingOperationsKey = "pending_operations"
    private let syncStatusKey = "sync_status_items"
    private let lastSyncKey = "last_sync_time"
    
    private var syncStatusItems: [String: SyncableItem] = [:]
    private var pendingOperations: [PendingOperation] = []
    
    private init() {
        setupEncoder()
        loadPendingOperations()
        loadSyncStatusItems()
        loadLastSyncTime()
        startNetworkMonitoring()
    }
    
    private func setupEncoder() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        // In a real app, use Network framework or Reachability
        // For now, simulate network status
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkNetworkStatus()
            }
        }
    }
    
    private func checkNetworkStatus() {
        // Simulate network check
        let wasOnline = isOnline
        isOnline = true // In real app, check actual network status
        
        if !wasOnline && isOnline {
            // Network came back online
            Task {
                await startSyncProcess()
            }
        }
        
        updateGlobalSyncStatus()
    }
    
    private func updateGlobalSyncStatus() {
        if !isOnline {
            syncStatus = .offline
        } else if !pendingOperations.isEmpty {
            syncStatus = .syncing
        } else if syncStatusItems.values.contains(where: { $0.syncStatus == .conflict }) {
            syncStatus = .conflict
        } else if syncStatusItems.values.contains(where: { $0.syncStatus == .failed }) {
            syncStatus = .failed
        } else {
            syncStatus = .synced
        }
    }
    
    // MARK: - Local Storage
    
    func saveGroups(_ groups: [Group]) {
        do {
            let data = try encoder.encode(groups)
            userDefaults.set(data, forKey: groupsKey)
            
            for group in groups {
                updateSyncStatus(for: group.id, status: .offline, isLocalOnly: true)
            }
        } catch {
            print("Failed to save groups locally: \(error)")
        }
    }
    
    func loadGroups() -> [Group] {
        guard let data = userDefaults.data(forKey: groupsKey) else { return [] }
        
        do {
            return try decoder.decode([Group].self, from: data)
        } catch {
            print("Failed to load groups locally: \(error)")
            return []
        }
    }
    
    func saveExpenses(_ expenses: [Expense]) {
        do {
            let data = try encoder.encode(expenses)
            userDefaults.set(data, forKey: expensesKey)
            
            for expense in expenses {
                updateSyncStatus(for: expense.id, status: .offline, isLocalOnly: true)
            }
        } catch {
            print("Failed to save expenses locally: \(error)")
        }
    }
    
    func loadExpenses() -> [Expense] {
        guard let data = userDefaults.data(forKey: expensesKey) else { return [] }
        
        do {
            return try decoder.decode([Expense].self, from: data)
        } catch {
            print("Failed to load expenses locally: \(error)")
            return []
        }
    }
    
    // MARK: - Pending Operations Queue
    
    func queueOperation(type: OperationType, data: Data) {
        let operation = PendingOperation(type: type, data: data)
        pendingOperations.append(operation)
        savePendingOperations()
        pendingOperationsCount = pendingOperations.count
        
        if isOnline {
            Task {
                await processNextOperation()
            }
        }
    }
    
    func queueGroupOperation<T: Codable>(type: OperationType, item: T) {
        do {
            let data = try encoder.encode(item)
            queueOperation(type: type, data: data)
        } catch {
            print("Failed to encode item for queue: \(error)")
        }
    }
    
    private func savePendingOperations() {
        do {
            let data = try encoder.encode(pendingOperations)
            userDefaults.set(data, forKey: pendingOperationsKey)
        } catch {
            print("Failed to save pending operations: \(error)")
        }
    }
    
    private func loadPendingOperations() {
        guard let data = userDefaults.data(forKey: pendingOperationsKey) else { return }
        
        do {
            pendingOperations = try decoder.decode([PendingOperation].self, from: data)
            pendingOperationsCount = pendingOperations.count
        } catch {
            print("Failed to load pending operations: \(error)")
        }
    }
    
    // MARK: - Sync Status Management
    
    func updateSyncStatus(for itemId: String, status: SyncStatus, isLocalOnly: Bool = false) {
        syncStatusItems[itemId] = SyncableItem(
            id: itemId,
            syncStatus: status,
            lastModified: Date(),
            isLocalOnly: isLocalOnly
        )
        saveSyncStatusItems()
        updateGlobalSyncStatus()
    }
    
    func getSyncStatus(for itemId: String) -> SyncStatus {
        return syncStatusItems[itemId]?.syncStatus ?? .offline
    }
    
    func getSyncableItem(for itemId: String) -> SyncableItem? {
        return syncStatusItems[itemId]
    }
    
    private func saveSyncStatusItems() {
        do {
            let data = try encoder.encode(syncStatusItems)
            userDefaults.set(data, forKey: syncStatusKey)
        } catch {
            print("Failed to save sync status items: \(error)")
        }
    }
    
    private func loadSyncStatusItems() {
        guard let data = userDefaults.data(forKey: syncStatusKey) else { return }
        
        do {
            syncStatusItems = try decoder.decode([String: SyncableItem].self, from: data)
        } catch {
            print("Failed to load sync status items: \(error)")
        }
    }
    
    private func loadLastSyncTime() {
        if let timestamp = userDefaults.object(forKey: lastSyncKey) as? Date {
            lastSyncTime = timestamp
        }
    }
    
    private func saveLastSyncTime() {
        userDefaults.set(lastSyncTime, forKey: lastSyncKey)
    }
    
    // MARK: - Sync Process
    
    func startSyncProcess() async {
        guard isOnline else { return }
        
        syncStatus = .syncing
        
        // Process all pending operations
        while !pendingOperations.isEmpty {
            await processNextOperation()
        }
        
        // Sync down any remote changes
        await syncRemoteChanges()
        
        lastSyncTime = Date()
        saveLastSyncTime()
        updateGlobalSyncStatus()
    }
    
    private func processNextOperation() async {
        guard !pendingOperations.isEmpty else { return }
        
        let operation = pendingOperations[0]
        
        do {
            try await executeOperation(operation)
            pendingOperations.removeFirst()
            savePendingOperations()
            pendingOperationsCount = pendingOperations.count
        } catch {
            print("Failed to execute operation: \(error)")
            
            // Increment retry count
            pendingOperations[0].retryCount += 1
            
            // If too many retries, mark as failed and remove
            if pendingOperations[0].retryCount >= 3 {
                pendingOperations.removeFirst()
                savePendingOperations()
                pendingOperationsCount = pendingOperations.count
            }
        }
    }
    
    private func executeOperation(_ operation: PendingOperation) async throws {
        let cloudKitManager = CloudKitManager.shared
        
        switch operation.type {
        case .createGroup:
            let group = try decoder.decode(Group.self, from: operation.data)
            let savedGroup = try await cloudKitManager.saveGroup(group)
            updateSyncStatus(for: savedGroup.id, status: .synced)
            
        case .updateGroup:
            let group = try decoder.decode(Group.self, from: operation.data)
            let savedGroup = try await cloudKitManager.saveGroup(group)
            updateSyncStatus(for: savedGroup.id, status: .synced)
            
        case .deleteGroup:
            let group = try decoder.decode(Group.self, from: operation.data)
            // Note: CloudKit delete operations would need the actual record
            // For now, mark as synced
            updateSyncStatus(for: group.id, status: .synced)
            
        case .createExpense:
            let expense = try decoder.decode(Expense.self, from: operation.data)
            let savedExpense = try await cloudKitManager.saveExpense(expense)
            updateSyncStatus(for: savedExpense.id, status: .synced)
            
        case .updateExpense:
            let expense = try decoder.decode(Expense.self, from: operation.data)
            let savedExpense = try await cloudKitManager.saveExpense(expense)
            updateSyncStatus(for: savedExpense.id, status: .synced)
            
        case .deleteExpense:
            let expense = try decoder.decode(Expense.self, from: operation.data)
            // Note: CloudKit delete operations would need the actual record
            updateSyncStatus(for: expense.id, status: .synced)
        }
    }
    
    private func syncRemoteChanges() async {
        // In a real implementation, this would:
        // 1. Fetch changes from CloudKit since lastSyncTime
        // 2. Apply remote changes locally
        // 3. Handle conflicts using last-write-wins
        
        let cloudKitManager = CloudKitManager.shared
        
        do {
            // Clean version without debug prints
            guard cloudKitManager.isSignedInToiCloud else {
                print("❌ Not signed into iCloud, skipping sync")
                return
            }
            
            let remoteGroups = try await cloudKitManager.fetchGroupsAsModels()
            print("✅ Fetched \(remoteGroups.count) remote groups")
            
            // Validate groups before processing
            let validGroups = remoteGroups.filter { group in
                let isValid = !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                              group.participants.count >= 1 &&
                              group.totalSpent.isFinite &&
                              group.totalSpent >= 0
                if !isValid {
                    print("⚠️ Skipping invalid group: \(group.name)")
                }
                return isValid
            }
            
            let localGroups = loadGroups()
            print("📱 Found \(localGroups.count) local groups")
            
            let mergedGroups = mergeGroups(local: localGroups, remote: validGroups)
            print("🔀 Merged to \(mergedGroups.count) groups")
            saveGroups(mergedGroups)
            
            // Only sync expenses for valid groups
            await syncExpensesWithConcurrency(groups: mergedGroups, cloudKitManager: cloudKitManager)
            
            print("✅ Sync completed successfully")
            
        } catch {
            print("❌ Failed to sync remote changes: \(error)")
            
            // Don't print sensitive CloudKit error details in production
            if let cloudKitError = error as? CloudKitManagerError {
                print("CloudKit error type: \(cloudKitError)")
            }
        }
    }
    
    private func syncExpensesWithConcurrency(groups: [Group], cloudKitManager: CloudKitManager) async {
        let maxConcurrentOperations = 3 // Limit concurrent operations to prevent timeout
        
        await withTaskGroup(of: Void.self) { taskGroup in
            var operationCount = 0
            
            for (index, group) in groups.enumerated() {
                // Limit concurrent operations
                if operationCount >= maxConcurrentOperations {
                    // Wait for at least one operation to complete
                    _ = await taskGroup.next()
                    operationCount -= 1
                }
                
                taskGroup.addTask { [weak self] in
                    guard let self = self else { return }
                    do {
                        print("🔄 [\(index+1)/\(groups.count)] Fetching expenses for group: \(group.name)")
                        let remoteExpenses = try await cloudKitManager.fetchExpensesAsModels(for: group.id)
                        print("✅ Fetched \(remoteExpenses.count) remote expenses for \(group.name)")
                        
                        await MainActor.run {
                            let localExpenses = self.loadExpenses().filter { $0.groupReference == group.id }
                            print("📱 Found \(localExpenses.count) local expenses for \(group.name)")
                            
                            let mergedExpenses = self.mergeExpenses(local: localExpenses, remote: remoteExpenses)
                            print("🔀 Merged to \(mergedExpenses.count) expenses for \(group.name)")
                            
                            // Update local expenses for this group
                            var allLocalExpenses = self.loadExpenses().filter { $0.groupReference != group.id }
                            allLocalExpenses.append(contentsOf: mergedExpenses)
                            self.saveExpenses(allLocalExpenses)
                        }
                    } catch {
                        print("❌ Failed to sync expenses for group \(group.name): \(error)")
                    }
                }
                operationCount += 1
            }
            
            // Wait for all remaining tasks to complete
            for await _ in taskGroup {
                // Tasks will complete as they finish
            }
        }
    }
    
    // MARK: - Conflict Resolution (Last-Write-Wins)
    
    private func mergeGroups(local: [Group], remote: [Group]) -> [Group] {
        var merged: [String: Group] = [:]
        
        // Add all local groups
        for group in local {
            merged[group.id] = group
        }
        
        // Override with remote groups (last-write-wins)
        for remoteGroup in remote {
            if let localGroup = merged[remoteGroup.id] {
                // Compare last activity dates
                if remoteGroup.lastActivity > localGroup.lastActivity {
                    merged[remoteGroup.id] = remoteGroup
                    updateSyncStatus(for: remoteGroup.id, status: .synced)
                } else {
                    // Local is newer, keep local version but mark for sync
                    updateSyncStatus(for: localGroup.id, status: .conflict)
                }
            } else {
                // New remote group
                merged[remoteGroup.id] = remoteGroup
                updateSyncStatus(for: remoteGroup.id, status: .synced)
            }
        }
        
        return Array(merged.values)
    }
    
    private func mergeExpenses(local: [Expense], remote: [Expense]) -> [Expense] {
        var merged: [String: Expense] = [:]
        
        // Add all local expenses
        for expense in local {
            merged[expense.id] = expense
        }
        
        // Override with remote expenses (last-write-wins)
        for remoteExpense in remote {
            if let localExpense = merged[remoteExpense.id] {
                // Compare dates (using date as last modified)
                if remoteExpense.date > localExpense.date {
                    merged[remoteExpense.id] = remoteExpense
                    updateSyncStatus(for: remoteExpense.id, status: .synced)
                } else {
                    // Local is newer, keep local version but mark for sync
                    updateSyncStatus(for: localExpense.id, status: .conflict)
                }
            } else {
                // New remote expense
                merged[remoteExpense.id] = remoteExpense
                updateSyncStatus(for: remoteExpense.id, status: .synced)
            }
        }
        
        return Array(merged.values)
    }
    
    // MARK: - Public Interface
    
    func saveGroupOffline(_ group: Group) {
        var groups = loadGroups()
        
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        
        saveGroups(groups)
        queueGroupOperation(type: .createGroup, item: group)
        updateSyncStatus(for: group.id, status: isOnline ? .syncing : .offline, isLocalOnly: true)
    }
    
    func saveExpenseOffline(_ expense: Expense) {
        var expenses = loadExpenses()
        
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        } else {
            expenses.append(expense)
        }
        
        saveExpenses(expenses)
        queueGroupOperation(type: .createExpense, item: expense)
        updateSyncStatus(for: expense.id, status: isOnline ? .syncing : .offline, isLocalOnly: true)
    }
    
    func deleteGroupOffline(_ group: Group) {
        var groups = loadGroups()
        groups.removeAll { $0.id == group.id }
        saveGroups(groups)
        
        queueGroupOperation(type: .deleteGroup, item: group)
        updateSyncStatus(for: group.id, status: isOnline ? .syncing : .offline, isLocalOnly: true)
    }
    
    func deleteExpenseOffline(_ expense: Expense) {
        var expenses = loadExpenses()
        expenses.removeAll { $0.id == expense.id }
        saveExpenses(expenses)
        
        queueGroupOperation(type: .deleteExpense, item: expense)
        updateSyncStatus(for: expense.id, status: isOnline ? .syncing : .offline, isLocalOnly: true)
    }
    
    func forceSyncNow() async {
        await startSyncProcess()
    }
    
    func clearLocalData() {
        userDefaults.removeObject(forKey: groupsKey)
        userDefaults.removeObject(forKey: expensesKey)
        userDefaults.removeObject(forKey: pendingOperationsKey)
        userDefaults.removeObject(forKey: syncStatusKey)
        userDefaults.removeObject(forKey: lastSyncKey)
        
        pendingOperations.removeAll()
        syncStatusItems.removeAll()
        pendingOperationsCount = 0
        lastSyncTime = nil
        
        updateGlobalSyncStatus()
    }
}