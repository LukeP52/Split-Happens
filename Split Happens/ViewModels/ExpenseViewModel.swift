//
//  ExpenseViewModel.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import SwiftUI
import Combine

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
            let savedExpense = try await cloudKitManager.saveExpense(newExpense)
            expenses.append(savedExpense)
            
            // Update the group's total spent amount
            await updateGroupTotal(groupID: groupID)
            
            // Notify that groups data has changed so the main view refreshes
            NotificationCenter.default.post(name: .groupsDidChange, object: nil)
        } catch {
            errorMessage = "Failed to create expense: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateExpense(_ originalExpense: Expense, _ updatedExpense: Expense) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let savedExpense = try await cloudKitManager.saveExpense(updatedExpense)
            if let index = expenses.firstIndex(where: { $0.id == originalExpense.id }) {
                expenses[index] = savedExpense
            }
            
            // Update the group's total spent amount (recalculate from all expenses)
            await updateGroupTotal(groupID: updatedExpense.groupReference)
            
            // Notify that groups data has changed so the main view refreshes
            NotificationCenter.default.post(name: .groupsDidChange, object: nil)
        } catch {
            errorMessage = "Failed to update expense: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func deleteExpense(_ expense: Expense) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let record = expense.toCKRecord()
            try await cloudKitManager.deleteExpense(record)
            expenses.removeAll { $0.id == expense.id }
            
            // Update the group's total spent amount (recalculate from all expenses)
            await updateGroupTotal(groupID: expense.groupReference)
            
            // Notify that groups data has changed so the main view refreshes
            NotificationCenter.default.post(name: .groupsDidChange, object: nil)
        } catch {
            errorMessage = "Failed to delete expense: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Group Total Management
    
    private func updateGroupTotal(groupID: String) async {
        do {
            // Fetch the current group
            guard var group = try await cloudKitManager.fetchGroup(by: groupID) else {
                print("Could not find group with ID: \(groupID)")
                return
            }
            
            // Recalculate total from all expenses
            let allExpenses = try await cloudKitManager.fetchExpensesAsModels(for: groupID)
            let newTotal = allExpenses.reduce(0) { $0 + $1.totalAmount.safeValue }
            
            // Update the group with new total
            group.totalSpent = newTotal
            
            // Save the updated group
            let savedGroup = try await cloudKitManager.saveGroup(group)
            
            // Update local cache
            await MainActor.run {
                let offlineManager = OfflineStorageManager.shared
                var localGroups = offlineManager.loadGroups()
                if let index = localGroups.firstIndex(where: { $0.id == groupID }) {
                    localGroups[index] = savedGroup
                    offlineManager.saveGroups(localGroups)
                }
            }
            
            print("Updated group \(groupID) total to: \(newTotal)")
        } catch {
            print("Failed to update group total: \(error.localizedDescription)")
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