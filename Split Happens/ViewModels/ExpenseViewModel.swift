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
        } catch {
            errorMessage = "Failed to create expense: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateExpense(_ expense: Expense) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedExpense = try await cloudKitManager.saveExpense(expense)
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses[index] = updatedExpense
            }
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
        } catch {
            errorMessage = "Failed to delete expense: \(error.localizedDescription)"
        }
        
        isLoading = false
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
        return expenses.isEmpty ? 0 : totalAmount() / Double(expenses.count)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
} 