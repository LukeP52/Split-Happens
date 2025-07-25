//
//  UnifiedExpenseViewModel.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class UnifiedExpenseViewModel: ObservableObject {
    @Published var allExpenses: [ExpenseWithGroup] = []
    @Published var recentExpenses: [ExpenseWithGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager.shared
    private let groupViewModel = GroupViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotificationObservers()
        Task {
            await loadAllExpenses()
        }
    }
    
    // MARK: - Data Loading
    
    func loadAllExpenses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get all active groups
            let groups = groupViewModel?.groups ?? []
            var allExpensesWithGroups: [ExpenseWithGroup] = []
            
            // Fetch expenses for each group
            for group in groups {
                let expenses = try await cloudKitManager.fetchExpensesAsModels(for: group.id)
                let expensesWithGroup = expenses.map { ExpenseWithGroup(expense: $0, group: group) }
                allExpensesWithGroups.append(contentsOf: expensesWithGroup)
            }
            
            // Sort by date (most recent first)
            allExpenses = allExpensesWithGroups.sorted { $0.expense.date > $1.expense.date }
            
            // Get recent expenses (last 7 days)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            recentExpenses = allExpenses.filter { $0.expense.date >= weekAgo }
            
        } catch {
            errorMessage = "Failed to load expenses: \(error.localizedDescription)"
            ErrorHandler.shared.handle(error) {
                Task { await self.loadAllExpenses() }
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    var allActivity: [Activity] {
        return allExpenses.map { expenseWithGroup in
            Activity(
                id: expenseWithGroup.expense.id,
                type: .expense,
                title: expenseWithGroup.expense.description,
                subtitle: "in \(expenseWithGroup.group.name)",
                amount: expenseWithGroup.expense.totalAmount.safeValue,
                date: expenseWithGroup.expense.date,
                participants: [expenseWithGroup.expense.paidBy],
                groupName: expenseWithGroup.group.name
            )
        }
    }
    
    var totalSpentThisWeek: Double {
        recentExpenses.reduce(0) { $0 + $1.expense.totalAmount.safeValue }
    }
    
    var expensesByCategory: [ExpenseCategory: [ExpenseWithGroup]] {
        Dictionary(grouping: allExpenses) { $0.expense.category }
    }
    
    var topSpendingCategories: [(category: ExpenseCategory, amount: Double)] {
        expensesByCategory.map { (category, expenses) in
            let total = expenses.reduce(0) { $0 + $1.expense.totalAmount.safeValue }
            return (category: category, amount: total)
        }
        .sorted { $0.amount > $1.amount }
        .prefix(5)
        .map { $0 }
    }
    
    // MARK: - Filtering and Search
    
    func expenses(for category: ExpenseCategory) -> [ExpenseWithGroup] {
        return allExpenses.filter { $0.expense.category == category }
    }
    
    func expenses(in dateRange: ClosedRange<Date>) -> [ExpenseWithGroup] {
        return allExpenses.filter { dateRange.contains($0.expense.date) }
    }
    
    func searchExpenses(query: String) -> [ExpenseWithGroup] {
        guard !query.isEmpty else { return allExpenses }
        
        let lowercaseQuery = query.lowercased()
        return allExpenses.filter { expenseWithGroup in
            expenseWithGroup.expense.description.lowercased().contains(lowercaseQuery) ||
            expenseWithGroup.group.name.lowercased().contains(lowercaseQuery) ||
            expenseWithGroup.expense.paidBy.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .expensesDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadAllExpenses()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .groupsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadAllExpenses()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Models

struct ExpenseWithGroup: Identifiable {
    let expense: Expense
    let group: Group
    
    var id: String { expense.id }
}

struct Activity: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let amount: Double
    let date: Date
    let participants: [String]
    let groupName: String
    
    var formattedAmount: String {
        formatCurrency(amount)
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

enum ActivityType {
    case expense
    case payment
    case settlement
    
    var icon: String {
        switch self {
        case .expense:
            return "creditcard"
        case .payment:
            return "dollarsign.circle"
        case .settlement:
            return "arrow.left.arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .expense:
            return AppColors.accent
        case .payment:
            return AppColors.success
        case .settlement:
            return AppColors.warning
        }
    }
}