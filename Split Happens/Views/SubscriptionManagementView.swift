//
//  SubscriptionManagementView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI

struct SubscriptionManagementView: View {
    @StateObject private var subscriptionManager = CloudKitSubscriptionManager.shared
    @StateObject private var alertManager = AlertManager.shared
    @State private var showingDebugInfo = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                subscriptionStatusSection
                subscriptionsSection
                notificationSection
                testingSection
                debugSection
            }
            .navigationTitle("CloudKit Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshSubscriptions()
            }
        }
    }
    
    // MARK: - Sections
    
    private var subscriptionStatusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Status")
                        .font(.headline)
                    
                    Text(subscriptionManager.isSetupComplete ? "Complete" : "Pending")
                        .font(.subheadline)
                        .foregroundColor(subscriptionManager.isSetupComplete ? .green : .orange)
                }
                
                Spacer()
                
                Image(systemName: subscriptionManager.isSetupComplete ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundColor(subscriptionManager.isSetupComplete ? .green : .orange)
                    .font(.title2)
            }
            
            HStack {
                Text("Active Subscriptions")
                Spacer()
                Text("\(subscriptionManager.subscriptions.count)")
                    .foregroundColor(.secondary)
            }
            
            if !subscriptionManager.isSetupComplete {
                Button("Setup Subscriptions") {
                    Task {
                        await setupSubscriptions()
                    }
                }
                .disabled(isLoading)
            }
        } header: {
            Text("Status")
        }
    }
    
    private var subscriptionsSection: some View {
        Section {
            if subscriptionManager.subscriptions.isEmpty {
                Text("No subscriptions found")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(subscriptionManager.subscriptions) { subscription in
                    SubscriptionRowView(subscription: subscription)
                }
            }
        } header: {
            Text("Active Subscriptions")
        }
    }
    
    private var notificationSection: some View {
        Section {
            HStack {
                Text("Notifications Received")
                Spacer()
                Text("\(subscriptionManager.notificationCount)")
                    .foregroundColor(.secondary)
            }
            
            if let lastNotification = subscriptionManager.lastNotificationReceived {
                HStack {
                    Text("Last Notification")
                    Spacer()
                    Text(lastNotification, style: .relative)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("Last Notification")
                    Spacer()
                    Text("Never")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Notifications")
        }
    }
    
    private var testingSection: some View {
        Section {
            Button("Test Subscriptions") {
                Task {
                    await testSubscriptions()
                }
            }
            .disabled(isLoading)
            
            Button("Reset Subscriptions") {
                Task {
                    await resetSubscriptions()
                }
            }
            .disabled(isLoading)
            .foregroundColor(.orange)
            
            Button("Remove All Subscriptions") {
                Task {
                    await removeAllSubscriptions()
                }
            }
            .disabled(isLoading)
            .foregroundColor(.red)
        } header: {
            Text("Testing")
        } footer: {
            Text("Use these controls to test subscription functionality. 'Test Subscriptions' creates a temporary group to trigger notifications.")
        }
    }
    
    private var debugSection: some View {
        Section {
            Button("Show Debug Info") {
                showingDebugInfo = true
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Working...")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Debug")
        }
        .sheet(isPresented: $showingDebugInfo) {
            DebugInfoView()
        }
    }
    
    // MARK: - Actions
    
    private func refreshSubscriptions() async {
        isLoading = true
        await subscriptionManager.refreshSubscriptions()
        isLoading = false
    }
    
    private func setupSubscriptions() async {
        isLoading = true
        await subscriptionManager.setupSubscriptions()
        alertManager.showSubscriptionError("Subscriptions setup initiated")
        isLoading = false
    }
    
    private func testSubscriptions() async {
        isLoading = true
        await subscriptionManager.testSubscriptions()
        alertManager.showSubscriptionError("Test group created. You should receive a notification shortly.")
        isLoading = false
    }
    
    private func resetSubscriptions() async {
        isLoading = true
        await subscriptionManager.resetSubscriptions()
        alertManager.showSubscriptionError("Subscriptions have been reset")
        isLoading = false
    }
    
    private func removeAllSubscriptions() async {
        isLoading = true
        await subscriptionManager.removeAllSubscriptions()
        alertManager.showSubscriptionError("All subscriptions have been removed")
        isLoading = false
    }
}

// MARK: - Subscription Row View

struct SubscriptionRowView: View {
    let subscription: SubscriptionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.type.rawValue)
                        .font(.headline)
                    
                    Text(subscription.type.recordType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    StatusBadge(isActive: subscription.isActive)
                    
                    if let lastTriggered = subscription.lastTriggered {
                        Text(lastTriggered, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never triggered")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let errorMessage = subscription.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(isActive ? "Active" : "Inactive")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isActive ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((isActive ? Color.green : Color.red).opacity(0.1))
        )
    }
}

// MARK: - Debug Info View

struct DebugInfoView: View {
    @StateObject private var subscriptionManager = CloudKitSubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var debugInfo: [String: Any] {
        subscriptionManager.getDebugInfo()
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Debug Information") {
                    ForEach(debugInfo.keys.sorted(), id: \.self) { key in
                        DebugInfoRow(key: key, value: debugInfo[key])
                    }
                }
            }
            .navigationTitle("Debug Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DebugInfoRow: View {
    let key: String
    let value: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.headline)
            
            Text(String(describing: value ?? "nil"))
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Testing Helper View

struct SubscriptionTestingView: View {
    @StateObject private var subscriptionManager = CloudKitSubscriptionManager.shared
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("CloudKit Subscription Testing")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Run these tests on multiple devices/simulators to verify subscriptions work correctly.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                TestButton(title: "Test Group Creation") {
                    await testGroupCreation()
                }
                
                TestButton(title: "Test Expense Creation") {
                    await testExpenseCreation()
                }
                
                TestButton(title: "Test Group Update") {
                    await testGroupUpdate()
                }
                
                TestButton(title: "Clear Test Results") {
                    testResults.removeAll()
                }
            }
            .disabled(isRunningTests)
            
            if !testResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(testResults.indices, id: \.self) { index in
                            Text(testResults[index])
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(maxHeight: 200)
            }
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func TestButton(title: String, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task {
                isRunningTests = true
                await action()
                isRunningTests = false
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRunningTests)
    }
    
    private func testGroupCreation() async {
        addTestResult("Testing group creation...")
        
        let testGroup = Group(
            name: "Test Group \(Date().timeIntervalSince1970)",
            participants: ["User 1", "User 2"]
        )
        
        do {
            let cloudKitManager = CloudKitManager.shared
            let savedGroup = try await cloudKitManager.saveGroup(testGroup)
            addTestResult("✅ Group created: \(savedGroup.name)")
        } catch {
            addTestResult("❌ Failed to create group: \(error.localizedDescription)")
        }
    }
    
    private func testExpenseCreation() async {
        addTestResult("Testing expense creation...")
        
        // Create a test expense
        let testExpense = Expense(
            groupReference: "test-group-id",
            description: "Test Expense \(Date().timeIntervalSince1970)",
            totalAmount: 25.50,
            paidBy: "Test User",
            paidByID: "test-user-id"
        )
        
        do {
            let cloudKitManager = CloudKitManager.shared
            let savedExpense = try await cloudKitManager.saveExpense(testExpense)
            addTestResult("✅ Expense created: \(savedExpense.description)")
        } catch {
            addTestResult("❌ Failed to create expense: \(error.localizedDescription)")
        }
    }
    
    private func testGroupUpdate() async {
        addTestResult("Testing group update...")
        // This would update an existing group to trigger notifications
        addTestResult("ℹ️ Group update test requires existing group")
    }
    
    private func addTestResult(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testResults.append("[\(timestamp)] \(message)")
    }
}

#Preview {
    SubscriptionManagementView()
}