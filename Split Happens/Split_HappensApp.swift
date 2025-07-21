//
//  Split_HappensApp.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI
import UserNotifications

@main
struct Split_HappensApp: App {
    @StateObject private var subscriptionManager = CloudKitSubscriptionManager.shared
    @StateObject private var offlineManager = OfflineStorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .background(AppColors.background)
                .accentColor(AppColors.accent)
                .task {
                    await setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        await handleAppBecameActive()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .groupsDidChange)) { _ in
                    Task {
                        await handleGroupsChanged()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .expensesDidChange)) { notification in
                    Task {
                        await handleExpensesChanged(notification)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .dataDidRefresh)) { _ in
                    Task {
                        await handleDataRefresh()
                    }
                }
        }
    }
    
    // MARK: - App Lifecycle
    
    private func setupApp() async {
        print("Setting up Split Happens app...")
        
        // Set up push notification handling
        await setupPushNotifications()
        
        // Set up CloudKit subscriptions
        if !subscriptionManager.isSetupComplete {
            await subscriptionManager.setupSubscriptions()
        }
        
        // Initial data sync
        if offlineManager.isOnline {
            await offlineManager.forceSyncNow()
        }
        
        print("App setup complete")
    }
    
    private func setupPushNotifications() async {
        let center = UNUserNotificationCenter.current()
        
        // Set notification delegate
        await MainActor.run {
            center.delegate = NotificationDelegate.shared
        }
        
        // Register for remote notifications
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        // Define notification categories
        let groupUpdateCategory = UNNotificationCategory(
            identifier: "GROUP_UPDATE",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_GROUP",
                    title: "View Group",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let expenseUpdateCategory = UNNotificationCategory(
            identifier: "EXPENSE_UPDATE",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_EXPENSE",
                    title: "View Expense",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([groupUpdateCategory, expenseUpdateCategory])
    }
    
    private func handleAppBecameActive() async {
        print("App became active - refreshing subscriptions")
        await subscriptionManager.refreshSubscriptions()
        
        if offlineManager.isOnline {
            await offlineManager.forceSyncNow()
        }
    }
    
    // MARK: - Data Change Handlers
    
    private func handleGroupsChanged() async {
        print("Groups changed notification received")
        // The UI will automatically update through @Published properties
        // Additional custom logic can be added here
    }
    
    private func handleExpensesChanged(_ notification: Notification) async {
        print("Expenses changed notification received")
        if let recordID = notification.userInfo?["recordID"] as? String {
            print("Expense record changed: \(recordID)")
        }
    }
    
    private func handleDataRefresh() async {
        print("Data refresh notification received")
        // Trigger any additional refresh logic if needed
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("Notification received while app in foreground")
        
        // Show banner and play sound even when app is active
        completionHandler([.banner, .sound, .badge])
        
        // Handle CloudKit notification
        let userInfo = notification.request.content.userInfo
        Task {
            await CloudKitSubscriptionManager.shared.handleRemoteNotification(userInfo)
        }
    }
    
    // Handle notification response (when user taps notification)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("Notification response received: \(response.actionIdentifier)")
        
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Handle different actions
        switch actionIdentifier {
        case "VIEW_GROUP":
            handleViewGroupAction(userInfo: userInfo)
        case "VIEW_EXPENSE":
            handleViewExpenseAction(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            handleDefaultAction(userInfo: userInfo)
        default:
            print("Unknown action identifier: \(actionIdentifier)")
        }
        
        // Handle CloudKit notification
        Task {
            await CloudKitSubscriptionManager.shared.handleRemoteNotification(userInfo)
        }
        
        completionHandler()
    }
    
    private func handleViewGroupAction(userInfo: [AnyHashable: Any]) {
        print("View group action triggered")
        // Navigate to specific group
        // This would typically use deep linking or navigation state
    }
    
    private func handleViewExpenseAction(userInfo: [AnyHashable: Any]) {
        print("View expense action triggered")
        // Navigate to specific expense
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        print("Default notification action")
        // Navigate to main app view
    }
}

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("Registered for remote notifications")
        print("Device token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("Received remote notification in background")
        
        Task {
            await CloudKitSubscriptionManager.shared.handleRemoteNotification(userInfo)
            completionHandler(.newData)
        }
    }
}
