//
//  CloudKitSubscriptionManager.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import CloudKit
import SwiftUI
import UserNotifications

enum SubscriptionType: String, CaseIterable {
    case groupChanges = "group-changes"
    case expenseChanges = "expense-changes"
    case userGroupChanges = "user-group-changes"
    
    var recordType: String {
        switch self {
        case .groupChanges, .userGroupChanges:
            return "Group"
        case .expenseChanges:
            return "Expense"
        }
    }
}

struct SubscriptionInfo: Identifiable {
    let id: String
    let type: SubscriptionType
    let isActive: Bool
    let lastTriggered: Date?
    let errorMessage: String?
    
    init(subscription: CKSubscription, isActive: Bool = true, lastTriggered: Date? = nil, errorMessage: String? = nil) {
        self.id = subscription.subscriptionID
        self.type = SubscriptionType(rawValue: subscription.subscriptionID) ?? .groupChanges
        self.isActive = isActive
        self.lastTriggered = lastTriggered
        self.errorMessage = errorMessage
    }
}

@MainActor
class CloudKitSubscriptionManager: ObservableObject {
    static let shared = CloudKitSubscriptionManager()
    
    @Published var subscriptions: [SubscriptionInfo] = []
    @Published var isSetupComplete = false
    @Published var lastNotificationReceived: Date?
    @Published var notificationCount = 0
    
    private let container = CKContainer(identifier: "iCloud.SplitHappens")
    private let database: CKDatabase
    private let userDefaults = UserDefaults.standard
    
    // Keys for storing subscription state
    private let subscriptionsSetupKey = "cloudkit_subscriptions_setup"
    private let lastNotificationKey = "last_notification_received"
    private let notificationCountKey = "notification_count"
    
    private init() {
        self.database = container.privateCloudDatabase
        loadSubscriptionState()
    }
    
    // MARK: - Subscription Setup
    
    func setupSubscriptions() async {
        guard !isSetupComplete else {
            print("Subscriptions already set up")
            return
        }
        
        do {
            // Request notification permissions first
            await requestNotificationPermissions()
            
            // Remove any existing subscriptions to start fresh
            await removeAllSubscriptions()
            
            // Create new subscriptions
            try await createGroupSubscription()
            try await createExpenseSubscription()
            try await createUserGroupSubscription()
            
            await MainActor.run {
                self.isSetupComplete = true
                self.userDefaults.set(true, forKey: self.subscriptionsSetupKey)
            }
            
            print("CloudKit subscriptions set up successfully")
            
        } catch {
            print("Failed to set up subscriptions: \(error)")
            await MainActor.run {
                self.isSetupComplete = false
            }
        }
    }
    
    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
            }
        } catch {
            print("Failed to request notification permissions: \(error)")
        }
    }
    
    // MARK: - Individual Subscription Creation
    
    private func createGroupSubscription() async throws {
        let predicate = NSPredicate(value: true) // Subscribe to all groups
        let subscription = CKQuerySubscription(
            recordType: "Group",
            predicate: predicate,
            subscriptionID: SubscriptionType.groupChanges.rawValue,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.title = "Group Updated"
        notificationInfo.alertBody = "A group you belong to has been updated"
        notificationInfo.shouldBadge = true
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.category = "GROUP_UPDATE"
        
        subscription.notificationInfo = notificationInfo
        
        let savedSubscription = try await database.save(subscription)
        await MainActor.run {
            let info = SubscriptionInfo(subscription: savedSubscription)
            self.subscriptions.append(info)
        }
        
        print("Group subscription created: \(savedSubscription.subscriptionID)")
    }
    
    private func createExpenseSubscription() async throws {
        let predicate = NSPredicate(value: true) // Subscribe to all expenses
        let subscription = CKQuerySubscription(
            recordType: "Expense",
            predicate: predicate,
            subscriptionID: SubscriptionType.expenseChanges.rawValue,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.title = "New Expense"
        notificationInfo.alertBody = "A new expense has been added to one of your groups"
        notificationInfo.shouldBadge = true
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.category = "EXPENSE_UPDATE"
        
        subscription.notificationInfo = notificationInfo
        
        let savedSubscription = try await database.save(subscription)
        await MainActor.run {
            let info = SubscriptionInfo(subscription: savedSubscription)
            self.subscriptions.append(info)
        }
        
        print("Expense subscription created: \(savedSubscription.subscriptionID)")
    }
    
    private func createUserGroupSubscription() async throws {
        // Subscribe to groups where user is a participant
        // Note: In a real implementation, you'd filter by user ID
        let predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        let subscription = CKQuerySubscription(
            recordType: "Group",
            predicate: predicate,
            subscriptionID: SubscriptionType.userGroupChanges.rawValue,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.title = "Group Activity"
        notificationInfo.alertBody = "Activity in one of your groups"
        notificationInfo.shouldBadge = true
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.category = "USER_GROUP_UPDATE"
        
        subscription.notificationInfo = notificationInfo
        
        let savedSubscription = try await database.save(subscription)
        await MainActor.run {
            let info = SubscriptionInfo(subscription: savedSubscription)
            self.subscriptions.append(info)
        }
        
        print("User group subscription created: \(savedSubscription.subscriptionID)")
    }
    
    // MARK: - Subscription Management
    
    func refreshSubscriptions() async {
        do {
            let fetchedSubscriptions = try await database.allSubscriptions()
            await MainActor.run {
                self.subscriptions = fetchedSubscriptions.map { subscription in
                    SubscriptionInfo(subscription: subscription)
                }
            }
            print("Refreshed \(fetchedSubscriptions.count) subscriptions")
        } catch {
            print("Failed to refresh subscriptions: \(error)")
        }
    }
    
    func removeAllSubscriptions() async {
        do {
            let existingSubscriptions = try await database.allSubscriptions()
            
            for subscription in existingSubscriptions {
                try await database.deleteSubscription(withID: subscription.subscriptionID)
                print("Deleted subscription: \(subscription.subscriptionID)")
            }
            
            await MainActor.run {
                self.subscriptions.removeAll()
                self.isSetupComplete = false
                self.userDefaults.set(false, forKey: self.subscriptionsSetupKey)
            }
            
        } catch {
            print("Failed to remove subscriptions: \(error)")
        }
    }
    
    func removeSubscription(_ subscriptionID: String) async {
        do {
            try await database.deleteSubscription(withID: subscriptionID)
            await MainActor.run {
                self.subscriptions.removeAll { $0.id == subscriptionID }
            }
            print("Removed subscription: \(subscriptionID)")
        } catch {
            print("Failed to remove subscription \(subscriptionID): \(error)")
        }
    }
    
    // MARK: - Push Notification Handling
    
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        print("Received CloudKit notification: \(userInfo)")
        
        await MainActor.run {
            self.lastNotificationReceived = Date()
            self.notificationCount += 1
            self.userDefaults.set(self.lastNotificationReceived, forKey: self.lastNotificationKey)
            self.userDefaults.set(self.notificationCount, forKey: self.notificationCountKey)
        }
        
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            print("Failed to create CKNotification from userInfo")
            return
        }
        
        switch notification.notificationType {
        case .query:
            await handleQueryNotification(notification as! CKQueryNotification)
        case .database:
            await handleDatabaseNotification(notification as! CKDatabaseNotification)
        case .recordZone:
            await handleRecordZoneNotification(notification as! CKRecordZoneNotification)
        case .readNotification:
            print("Read notification received")
        @unknown default:
            print("Unknown notification type received")
        }
    }
    
    private func handleQueryNotification(_ notification: CKQueryNotification) async {
        print("Query notification received for subscription: \(notification.subscriptionID ?? "unknown")")
        
        guard let subscriptionID = notification.subscriptionID,
              let subscriptionType = SubscriptionType(rawValue: subscriptionID) else {
            print("Unknown subscription ID: \(notification.subscriptionID ?? "nil")")
            return
        }
        
        // Update subscription info
        await MainActor.run {
            if let index = self.subscriptions.firstIndex(where: { $0.id == subscriptionID }) {
                let updatedInfo = SubscriptionInfo(
                    subscription: CKQuerySubscription(
                        recordType: subscriptionType.recordType,
                        predicate: NSPredicate(value: true),
                        subscriptionID: subscriptionID,
                        options: []
                    ),
                    isActive: true,
                    lastTriggered: Date()
                )
                self.subscriptions[index] = updatedInfo
            }
        }
        
        // Handle the specific change
        switch subscriptionType {
        case .groupChanges, .userGroupChanges:
            await handleGroupChange(notification)
        case .expenseChanges:
            await handleExpenseChange(notification)
        }
        
        // Refresh local data
        await refreshLocalData()
    }
    
    private func handleDatabaseNotification(_ notification: CKDatabaseNotification) async {
        print("Database notification received")
        await refreshLocalData()
    }
    
    private func handleRecordZoneNotification(_ notification: CKRecordZoneNotification) async {
        print("Record zone notification received")
        await refreshLocalData()
    }
    
    // MARK: - Specific Change Handlers
    
    private func handleGroupChange(_ notification: CKQueryNotification) async {
        print("Group change detected")
        
        if let recordID = notification.recordID {
            print("Group changed: \(recordID.recordName)")
            
            // Fetch the updated group
            do {
                let record = try await database.record(for: recordID)
                if let group = Group(from: record) {
                    await updateLocalGroup(group)
                }
            } catch {
                print("Failed to fetch updated group: \(error)")
            }
        }
        
        // Post notification for UI updates
        await MainActor.run {
            NotificationCenter.default.post(name: .groupsDidChange, object: nil)
        }
    }
    
    private func handleExpenseChange(_ notification: CKQueryNotification) async {
        print("Expense change detected")
        
        if let recordID = notification.recordID {
            print("Expense changed: \(recordID.recordName)")
            
            // Fetch the updated expense
            do {
                let record = try await database.record(for: recordID)
                if let expense = Expense(from: record) {
                    await updateLocalExpense(expense)
                }
            } catch {
                print("Failed to fetch updated expense: \(error)")
            }
        }
        
        // Post notification for UI updates
        await MainActor.run {
            NotificationCenter.default.post(
                name: .expensesDidChange,
                object: nil,
                userInfo: ["recordID": notification.recordID?.recordName ?? ""]
            )
        }
    }
    
    // MARK: - Local Data Updates
    
    private func updateLocalGroup(_ group: Group) async {
        let offlineManager = OfflineStorageManager.shared
        var localGroups = offlineManager.loadGroups()
        
        if let index = localGroups.firstIndex(where: { $0.id == group.id }) {
            localGroups[index] = group
        } else {
            localGroups.append(group)
        }
        
        offlineManager.saveGroups(localGroups)
        offlineManager.updateSyncStatus(for: group.id, status: .synced)
        
        print("Updated local group: \(group.name)")
    }
    
    private func updateLocalExpense(_ expense: Expense) async {
        let offlineManager = OfflineStorageManager.shared
        var localExpenses = offlineManager.loadExpenses()
        
        if let index = localExpenses.firstIndex(where: { $0.id == expense.id }) {
            localExpenses[index] = expense
        } else {
            localExpenses.append(expense)
        }
        
        offlineManager.saveExpenses(localExpenses)
        offlineManager.updateSyncStatus(for: expense.id, status: .synced)
        
        print("Updated local expense: \(expense.description)")
    }
    
    private func refreshLocalData() async {
        print("Refreshing local data due to remote changes")
        
        // Trigger a full sync
        let offlineManager = OfflineStorageManager.shared
        await offlineManager.forceSyncNow()
        
        // Post global refresh notification
        await MainActor.run {
            NotificationCenter.default.post(name: .dataDidRefresh, object: nil)
        }
    }
    
    // MARK: - State Persistence
    
    private func loadSubscriptionState() {
        isSetupComplete = userDefaults.bool(forKey: subscriptionsSetupKey)
        
        if let lastNotification = userDefaults.object(forKey: lastNotificationKey) as? Date {
            lastNotificationReceived = lastNotification
        }
        
        notificationCount = userDefaults.integer(forKey: notificationCountKey)
    }
    
    // MARK: - Testing Support
    
    func testSubscriptions() async {
        print("Testing CloudKit subscriptions...")
        
        // Create a test group to trigger notifications
        let testGroup = Group(
            name: "Test Group \(Date().timeIntervalSince1970)",
            participants: ["Test User 1", "Test User 2"]
        )
        
        do {
            let record = testGroup.toCKRecord()
            let savedRecord = try await database.save(record)
            print("Created test group: \(savedRecord.recordID.recordName)")
            
            // Delete it after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                Task {
                    do {
                        try await self.database.deleteRecord(withID: savedRecord.recordID)
                        print("Deleted test group")
                    } catch {
                        print("Failed to delete test group: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to create test group: \(error)")
        }
    }
    
    func resetSubscriptions() async {
        await removeAllSubscriptions()
        await setupSubscriptions()
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() -> [String: Any] {
        return [
            "isSetupComplete": isSetupComplete,
            "subscriptionCount": subscriptions.count,
            "lastNotificationReceived": lastNotificationReceived?.description ?? "Never",
            "notificationCount": notificationCount,
            "subscriptions": subscriptions.map { sub in
                [
                    "id": sub.id,
                    "type": sub.type.rawValue,
                    "isActive": sub.isActive,
                    "lastTriggered": sub.lastTriggered?.description ?? "Never"
                ]
            }
        ]
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let groupsDidChange = Notification.Name("groupsDidChange")
    static let expensesDidChange = Notification.Name("expensesDidChange")
    static let dataDidRefresh = Notification.Name("dataDidRefresh")
    static let subscriptionsDidUpdate = Notification.Name("subscriptionsDidUpdate")
}