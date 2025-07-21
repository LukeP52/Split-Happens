//
//  GroupDetailView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI

struct GroupDetailView: View {
    let group: Group
    @StateObject private var expenseViewModel = ExpenseViewModel()
    @StateObject private var offlineManager = OfflineStorageManager.shared
    @StateObject private var alertManager = AlertManager.shared
    @State private var showingAddExpense = false
    @State private var showingGroupSettings = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            GroupHeaderView(group: group, expenseViewModel: expenseViewModel)
            
            Picker("View", selection: $selectedTab) {
                Label("Expenses", systemImage: "list.bullet")
                    .tag(0)
                Label("Balances", systemImage: "scale.3d")
                    .tag(1)
                Label("Summary", systemImage: "chart.pie")
                    .tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(AppColors.tertiaryBackground)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            TabView(selection: $selectedTab) {
                ExpensesTabView(group: group, expenseViewModel: expenseViewModel)
                    .tag(0)
                
                BalancesTabView(group: group, expenseViewModel: expenseViewModel)
                    .tag(1)
                
                SummaryTabView(group: group, expenseViewModel: expenseViewModel)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingGroupSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(group: group, expenseViewModel: expenseViewModel)
        }
        .sheet(isPresented: $showingGroupSettings) {
            GroupSettingsView(group: group)
        }
        .task {
            await loadExpensesOfflineFirst()
        }
        .onReceive(expenseViewModel.$errorMessage) { errorMessage in
            guard let message = errorMessage else { return }
            Task { @MainActor in
                alertManager.showExpenseError(message)
                expenseViewModel.clearError()
            }
        }
    }
    
    // MARK: - Offline-First Methods
    
    private func loadExpensesOfflineFirst() async {
        // Load from cache immediately
        let cachedExpenses = offlineManager.loadExpenses().filter { $0.groupReference == group.id }
        if !cachedExpenses.isEmpty {
            await MainActor.run {
                expenseViewModel.expenses = cachedExpenses
            }
        }
        
        // Try to sync in background
        if offlineManager.isOnline {
            await expenseViewModel.loadExpenses(for: group.id)
        }
    }
}

struct GroupHeaderView: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    private var totalSpent: Double {
        guard !expenseViewModel.expenses.isEmpty else { return 0 }
        let result = expenseViewModel.expenses.reduce(0) { total, expense in
            guard expense.totalAmount.isFinite && expense.totalAmount >= 0 else { return total }
            return total + expense.totalAmount
        }
        return result.isFinite ? result : 0
    }
    
    private var expenseCount: Int {
        expenseViewModel.expenses.count
    }
    
    private var averagePerPerson: Double {
        guard group.participantCount > 0, totalSpent > 0 else { return 0 }
        let result = totalSpent / Double(group.participantCount)
        return result.isFinite ? result : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.participants, id: \.self) { participant in
                        ParticipantAvatarView(participant: participant)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatCurrency(totalSpent, currency: group.currency))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accent)
                    Text("Total Spent • \(expenseCount) expenses")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(AppColors.secondaryBackground)
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

struct ParticipantAvatarView: View {
    let participant: String
    
    private var initials: String {
        let components = participant.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            return String(participant.prefix(2))
        }
    }
    
    private var backgroundColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .cyan, .yellow]
        let hash = participant.hash
        return colors[abs(hash) % colors.count]
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(backgroundColor.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initials.uppercased())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(backgroundColor)
                )
            
            Text(participant.split(separator: " ").first?.description ?? participant)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExpensesTabView: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    private var sortedExpenses: [Expense] {
        expenseViewModel.expenses.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        List {
            if expenseViewModel.expenses.isEmpty {
                EmptyExpenseView()
                    .listRowInsets(EdgeInsets(top: 40, leading: 20, bottom: 40, trailing: 20))
            } else {
                ForEach(sortedExpenses) { expense in
                    NavigationLink(destination: ExpenseDetailView(expense: expense, group: group)) {
                        ExpenseRowViewWithSync(expense: expense, group: group)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button("Delete") {
                            Task {
                                await deleteExpenseOfflineFirst(expense)
                            }
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .refreshable {
            await loadExpensesOfflineFirst()
        }
    }
    
    private func deleteExpenseOfflineFirst(_ expense: Expense) async {
        let offlineManager = OfflineStorageManager.shared
        if offlineManager.isOnline {
            await expenseViewModel.deleteExpense(expense)
        } else {
            offlineManager.deleteExpenseOffline(expense)
            await MainActor.run {
                expenseViewModel.expenses.removeAll { $0.id == expense.id }
            }
        }
    }
    
    private func loadExpensesOfflineFirst() async {
        let offlineManager = OfflineStorageManager.shared
        // Load from cache immediately
        let cachedExpenses = offlineManager.loadExpenses().filter { $0.groupReference == group.id }
        if !cachedExpenses.isEmpty {
            await MainActor.run {
                expenseViewModel.expenses = cachedExpenses
            }
        }
        
        // Try to sync in background
        if offlineManager.isOnline {
            await expenseViewModel.loadExpenses(for: group.id)
        }
    }
}

struct LoadingExpenseRow: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading expenses...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
}

struct EmptyExpenseView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 60))
                .foregroundColor(AppColors.tertiaryText)
            
            Text("No Expenses Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText)
            
            Text("Add your first expense to start tracking shared costs")
                .font(.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .listRowBackground(Color.clear)
    }
}

struct ExpenseRowViewWithSync: View {
    let expense: Expense
    let group: Group
    
    var body: some View {
        ExpenseRowView(expense: expense, group: group)
    }
}

struct ExpenseRowView: View {
    let expense: Expense
    let group: Group
    
    private var categoryColor: Color {
        switch expense.category {
        case .food: return AppColors.categoryFood
        case .transportation: return AppColors.categoryTransport
        case .entertainment: return AppColors.categoryEntertainment
        case .utilities: return AppColors.categoryUtilities
        case .rent: return AppColors.categoryRent
        case .shopping: return AppColors.categoryShopping
        case .travel: return AppColors.categoryTravel
        case .other: return AppColors.categoryOther
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.icon)
                .font(.title2)
                .foregroundColor(categoryColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Text("\(expense.paidBy) • \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(formatCurrency(expense.totalAmount, currency: group.currency))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accent)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(AppColors.cardBackground)
        .elegantCard()
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}


struct GroupSettingsView: View {
    let group: Group
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Group Information") {
                    LabeledContent("Name", value: group.name)
                    LabeledContent("Currency", value: group.currency)
                    LabeledContent("Created", value: group.lastActivity.formatted(date: .abbreviated, time: .omitted))
                }
                
                Section("Participants") {
                    ForEach(group.participants, id: \.self) { participant in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(participant)
                        }
                    }
                }
            }
            .navigationTitle("Group Settings")
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

#Preview {
    NavigationView {
        GroupDetailView(group: Group(name: "Sample Group", participants: ["Alice", "Bob", "Charlie"]))
    }
} 