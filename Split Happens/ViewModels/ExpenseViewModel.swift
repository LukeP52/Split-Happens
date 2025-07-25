//
//  ExpenseViewModel.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import SwiftUI
import Combine
import CloudKit

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager.shared
    private let expenseCalculator = ExpenseCalculator.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentGroupID: String?
    
    init() {
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .expensesDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleExpenseChangeNotification(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .dataDidRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshExpensesFromNotification()
            }
            .store(in: &cancellables)
    }
    
    private func handleExpenseChangeNotification(_ notification: Notification) {
        if let recordID = notification.userInfo?["recordID"] as? String {
            refreshSpecificExpense(recordID)
        } else {
            refreshExpensesFromNotification()
        }
    }
    
    private func refreshExpensesFromNotification() {
        guard let groupID = currentGroupID else { return }
        Task {
            await loadExpenses(for: groupID)
        }
    }
    
    private func refreshSpecificExpense(_ recordID: String) {
        // Try to find and refresh a specific expense
        if expenses.first(where: { $0.id == recordID }) != nil {
            guard let groupID = currentGroupID else { return }
            Task {
                await loadExpenses(for: groupID)
            }
        }
    }
    
    // MARK: - Expense Operations
    
    func loadExpenses(for groupID: String) async {
        currentGroupID = groupID
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedExpenses = try await cloudKitManager.fetchExpensesAsModels(for: groupID)
            expenses = fetchedExpenses
        } catch {
            errorMessage = "Failed to load expenses: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createExpense(
        groupID: String,
        description: String,
        totalAmount: Double,
        paidBy: String,
        paidByID: String,
        splitType: SplitType = .equal,
        category: ExpenseCategory = .other,
        participantNames: [String] = []
    ) async {
        isLoading = true
        errorMessage = nil
        
        let newExpense = Expense(
            groupReference: groupID,
            description: description,
            totalAmount: totalAmount,
            paidBy: paidBy,
            paidByID: paidByID,
            splitType: splitType,
            category: category,
            participantNames: participantNames
        )
        
        do {
            // Step 1: Save expense and wait for completion
            let savedExpense = try await cloudKitManager.saveExpense(newExpense)
            print("✅ Expense saved successfully: \(savedExpense.description)")
            
            // Step 2: Calculate new total by adding this expense to current total (no refetch needed!)
            await updateGroupTotalWithNewExpense(groupID: groupID, expenseAmount: savedExpense.totalAmount.safeValue)
            print("✅ Group total updated for group: \(groupID)")
            
            // Step 3: Add to local array (this will trigger UI update)
            expenses.append(savedExpense)
            
            // Step 4: Notify that groups data has changed so the main view refreshes with correct total
            NotificationCenter.default.post(name: .groupsDidChange, object: nil)
            print("✅ UI notified to refresh with updated totals")
        } catch {
            errorMessage = "Failed to create expense: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateExpense(_ originalExpense: Expense, _ updatedExpense: Expense) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Save updated expense and wait for completion
            let savedExpense = try await cloudKitManager.saveExpense(updatedExpense)
            print("✅ Expense updated successfully: \(savedExpense.description)")
            
            // Step 2: Calculate difference and update group total (no refetch needed!)
            let amountDifference = savedExpense.totalAmount.safeValue - originalExpense.totalAmount.safeValue
            await updateGroupTotalWithExpenseDifference(groupID: updatedExpense.groupReference, amountDifference: amountDifference)
            print("✅ Group total updated for group: \(updatedExpense.groupReference)")
            
            // Step 3: Update local array (this will trigger UI update)
            if let index = expenses.firstIndex(where: { $0.id == originalExpense.id }) {
                expenses[index] = savedExpense
            }
            
            // Step 4: Notify that groups data has changed so the main view refreshes with correct total
            NotificationCenter.default.post(name: .groupsDidChange, object: nil)
            print("✅ UI notified to refresh with updated totals")
        } catch {
            errorMessage = "Failed to update expense: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func deleteExpense(_ expense: Expense) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Delete expense and wait for completion
            let record = expense.toCKRecord()
            try await cloudKitManager.deleteExpense(record)
            print("✅ Expense deleted successfully: \(expense.description)")
            
            // Step 2: Subtract expense amount from group total (no refetch needed!)
            await updateGroupTotalWithExpenseDifference(groupID: expense.groupReference, amountDifference: -expense.totalAmount.safeValue)
            print("✅ Group total updated for group: \(expense.groupReference)")
            
            // Step 3: Remove from local array (this will trigger UI update)
            expenses.removeAll { $0.id == expense.id }
            
            // Step 4: Notify that groups data has changed so the main view refreshes with correct total
            NotificationCenter.default.post(name: .groupsDidChange, object: nil)
            print("✅ UI notified to refresh with updated totals")
        } catch {
            errorMessage = "Failed to delete expense: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Group Total Management
    
    private func updateGroupTotalWithNewExpense(groupID: String, expenseAmount: Double) async {
        do {
            print("💰 Updating group total by adding expense amount: \(expenseAmount)")
            
            // First, get the most current total by fetching the fresh group from CloudKit
            guard let freshGroup = try await cloudKitManager.fetchGroup(by: groupID) else {
                print("❌ Group not found: \(groupID)")
                return
            }
            
            // Use the fresh total from CloudKit as the starting point
            let currentTotal = freshGroup.totalSpent
            let newTotal = currentTotal + expenseAmount
            print("💰 New total calculated: \(currentTotal) + \(expenseAmount) = \(newTotal)")
            
            // Update the group model with the new total
            var updatedGroup = freshGroup
            updatedGroup.totalSpent = newTotal
            updatedGroup.lastActivity = Date()
            
            // Save back to CloudKit and wait for completion
            let savedGroup = try await cloudKitManager.saveGroup(updatedGroup)
            print("✅ Group saved to CloudKit with new total: \(savedGroup.totalSpent)")
            
            // Update local cache synchronously and wait for completion
            await MainActor.run {
                // Update in GroupViewModel if available
                if let groupViewModel = GroupViewModel.shared {
                    if let index = groupViewModel.groups.firstIndex(where: { $0.id == groupID }) {
                        groupViewModel.groups[index] = savedGroup
                        print("✅ Updated GroupViewModel cache")
                    }
                }
                
                // Update offline storage
                let offlineManager = OfflineStorageManager.shared
                var localGroups = offlineManager.loadGroups()
                if let index = localGroups.firstIndex(where: { $0.id == groupID }) {
                    localGroups[index] = savedGroup
                    offlineManager.saveGroups(localGroups)
                    print("✅ Updated offline storage cache")
                }
            }
            
            print("✅ Group total update completed: \(groupID) -> \(newTotal)")
        } catch {
            print("❌ Failed to update group total with new expense: \(error)")
        }
    }
    
    private func updateGroupTotalWithExpenseDifference(groupID: String, amountDifference: Double) async {
        do {
            print("💰 Updating group total with difference: \(amountDifference)")
            
            // First, get the most current total by fetching the fresh group from CloudKit
            guard let freshGroup = try await cloudKitManager.fetchGroup(by: groupID) else {
                print("❌ Group not found: \(groupID)")
                return
            }
            
            // Use the fresh total from CloudKit as the starting point
            let currentTotal = freshGroup.totalSpent
            let newTotal = currentTotal + amountDifference
            print("💰 New total calculated: \(currentTotal) + \(amountDifference) = \(newTotal)")
            
            // Update the group model with the new total
            var updatedGroup = freshGroup
            updatedGroup.totalSpent = newTotal
            updatedGroup.lastActivity = Date()
            
            // Save back to CloudKit and wait for completion
            let savedGroup = try await cloudKitManager.saveGroup(updatedGroup)
            print("✅ Group saved to CloudKit with new total: \(savedGroup.totalSpent)")
            
            // Update local cache synchronously and wait for completion
            await MainActor.run {
                // Update in GroupViewModel if available
                if let groupViewModel = GroupViewModel.shared {
                    if let index = groupViewModel.groups.firstIndex(where: { $0.id == groupID }) {
                        groupViewModel.groups[index] = savedGroup
                        print("✅ Updated GroupViewModel cache")
                    }
                }
                
                // Update offline storage
                let offlineManager = OfflineStorageManager.shared
                var localGroups = offlineManager.loadGroups()
                if let index = localGroups.firstIndex(where: { $0.id == groupID }) {
                    localGroups[index] = savedGroup
                    offlineManager.saveGroups(localGroups)
                    print("✅ Updated offline storage cache")
                }
            }
            
            print("✅ Group total update completed with difference: \(groupID) -> \(newTotal)")
        } catch {
            print("❌ Failed to update group total with difference: \(error)")
        }
    }
    
    private func forceUpdateGroupTotal(groupID: String) async {
        do {
            print("🔄 Starting group total update for: \(groupID)")
            
            // Fetch the group using the public method
            guard let currentGroup = try await cloudKitManager.fetchGroup(by: groupID) else {
                print("❌ Group not found: \(groupID)")
                return
            }
            
            // Calculate new total from all expenses (fetch fresh from CloudKit)
            let allExpenses = try await cloudKitManager.fetchExpensesAsModels(for: groupID)
            let newTotal = allExpenses.reduce(0) { $0 + $1.totalAmount.safeValue }
            print("🔄 Calculated new total: \(newTotal) from \(allExpenses.count) expenses")
            
            // Only update if the total has actually changed
            guard abs(currentGroup.totalSpent - newTotal) > 0.01 else {
                print("✅ Group total already up to date: \(newTotal)")
                return
            }
            
            // Update the group model
            var updatedGroup = currentGroup
            updatedGroup.totalSpent = newTotal
            updatedGroup.lastActivity = Date()
            
            // Save back to CloudKit and wait for completion
            let savedGroup = try await cloudKitManager.saveGroup(updatedGroup)
            print("✅ Group saved to CloudKit with new total: \(savedGroup.totalSpent)")
            
            // Update local cache synchronously and wait for completion
            await MainActor.run {
                // Update in GroupViewModel if available
                if let groupViewModel = GroupViewModel.shared {
                    if let index = groupViewModel.groups.firstIndex(where: { $0.id == groupID }) {
                        groupViewModel.groups[index] = savedGroup
                        print("✅ Updated GroupViewModel cache")
                    }
                }
                
                // Update offline storage
                let offlineManager = OfflineStorageManager.shared
                var localGroups = offlineManager.loadGroups()
                if let index = localGroups.firstIndex(where: { $0.id == groupID }) {
                    localGroups[index] = savedGroup
                    offlineManager.saveGroups(localGroups)
                    print("✅ Updated offline storage cache")
                }
            }
            
            print("✅ Group total update completed: \(groupID) -> \(newTotal)")
        } catch {
            print("❌ Failed to update group total: \(error)")
        }
    }
    
    // MARK: - Balance Calculations
    
    func calculateBalances(for group: Group) -> [Balance] {
        return expenseCalculator.calculateNetBalances(for: group, expenses: expenses)
    }
    
    
    func suggestSettlements(for group: Group) -> [Settlement] {
        let balances = calculateBalances(for: group)
        return expenseCalculator.simplifyDebts(balances: balances)
    }
    
    // MARK: - Summary Statistics
    
    func calculateGroupSummary(for group: Group) -> (totalSpent: Double, averagePerPerson: Double, expenseCount: Int) {
        let summary = expenseCalculator.calculateGroupSummary(for: group, expenses: expenses)
        return (summary.totalSpent, summary.averagePerPerson, summary.expenseCount)
    }
    
    // MARK: - Filtering and Sorting
    
    func expensesByCategory() -> [ExpenseCategory: [Expense]] {
        return Dictionary(grouping: expenses) { $0.category }
    }
    
    func expensesByParticipant(_ participant: String) -> [Expense] {
        return expenses.filter { $0.paidBy == participant }
    }
    
    func sortedExpenses() -> [Expense] {
        return expenses.sorted { $0.date > $1.date }
    }
    
    func expensesInDateRange(from startDate: Date, to endDate: Date) -> [Expense] {
        return expenses.filter { expense in
            expense.date >= startDate && expense.date <= endDate
        }
    }
    
    // MARK: - Helper Methods
    
    func expense(with id: String) -> Expense? {
        return expenses.first { $0.id == id }
    }
    
    func totalAmount() -> Double {
        return expenses.reduce(0) { total, expense in
            guard expense.totalAmount.isFinite else { return total }
            return total + expense.totalAmount
        }
    }
    
    func averageAmount() -> Double {
        guard !expenses.isEmpty else { return 0 }
        let total = totalAmount()
        guard total.isFinite else { return 0 }
        let count = Double(expenses.count)
        guard count > 0 else { return 0 }
        let result = total / count
        return result.isFinite ? result : 0
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
} 