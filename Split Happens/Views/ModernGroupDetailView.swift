// ModernGroupDetailView.swift
import SwiftUI

struct ModernGroupDetailView: View {
    let group: Group
    @StateObject private var expenseViewModel = ExpenseViewModel()
    @State private var showingAddExpense = false
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Custom navigation bar
                    customNavBar
                    
                    // Header with stats
                    headerSection
                    
                    // Tab selector
                    tabSelector
                    
                    // Content based on selected tab
                    tabContent
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .bottomTrailing) {
            // Floating action button
            CircularIconButton(
                icon: "plus",
                size: 56,
                action: { showingAddExpense = true }
            )
            .padding(.trailing, 24)
            .padding(.bottom, 40)
            .shadow(color: AppColors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .fullScreenCover(isPresented: $showingAddExpense) {
            ModernAddExpenseView(group: group, expenseViewModel: expenseViewModel)
        }
        .task {
            await expenseViewModel.loadExpenses(for: group.id)
        }
    }
    
    private var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Circle()
                    .fill(AppColors.tertiaryBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primaryText)
                    )
            }
            
            Spacer()
            
            Text(group.name)
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Button(action: {}) {
                Circle()
                    .fill(AppColors.tertiaryBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primaryText)
                    )
            }
        }
        .padding(.top, 8)
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Participant avatars
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(group.participants, id: \.self) { participant in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.accent.opacity(0.3), AppColors.accentSecondary.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(participant.prefix(2).uppercased())
                                        .font(AppFonts.bodyMedium)
                                        .foregroundColor(AppColors.accent)
                                )
                            
                            Text(String(participant.split(separator: " ").first ?? Substring(participant)))
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // Stats cards
            HStack(spacing: 12) {
                StatMiniCard(
                    title: "Total Spent",
                    value: formatCurrency(calculateTotalSpent()),
                    icon: "dollarsign.circle.fill",
                    color: AppColors.accent
                )
                
                StatMiniCard(
                    title: "Expenses",
                    value: "\(expenseViewModel.expenses.count)",
                    icon: "list.bullet.circle.fill",
                    color: AppColors.success
                )
                
                StatMiniCard(
                    title: "Avg/Person",
                    value: formatCurrency(calculateAveragePerPerson()),
                    icon: "person.2.circle.fill",
                    color: AppColors.warning
                )
            }
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: "Expenses", icon: "list.bullet", isSelected: selectedTab == 0) {
                withAnimation { selectedTab = 0 }
            }
            
            TabButton(title: "Balances", icon: "scale.3d", isSelected: selectedTab == 1) {
                withAnimation { selectedTab = 1 }
            }
            
            TabButton(title: "Stats", icon: "chart.pie.fill", isSelected: selectedTab == 2) {
                withAnimation { selectedTab = 2 }
            }
        }
        .padding(4)
        .background(AppColors.tertiaryBackground)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            ModernExpensesTab(group: group, expenseViewModel: expenseViewModel)
        case 1:
            ModernBalancesTab(group: group, expenseViewModel: expenseViewModel)
        case 2:
            ModernStatsTab(group: group, expenseViewModel: expenseViewModel)
        default:
            EmptyView()
        }
    }
    
    private func calculateTotalSpent() -> Double {
        let total = expenseViewModel.expenses.reduce(0) { sum, expense in
            sum + expense.totalAmount.safeValue
        }
        return total.safeValue
    }
    
    private func calculateAveragePerPerson() -> Double {
        guard group.participantCount > 0 else { return 0 }
        let total = calculateTotalSpent()
        let average = total / Double(group.participantCount)
        return average.safeValue
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = group.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Components

struct StatMiniCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(title)
                    .font(AppFonts.footnote)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(AppColors.cardBackground)
        .modernCard()
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(AppFonts.captionMedium)
            }
            .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: 44)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppColors.accent : Color.clear)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Tab Views

struct ModernExpensesTab: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var sortedExpenses: [Expense] {
        expenseViewModel.expenses.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if sortedExpenses.isEmpty {
                ModernEmptyState(
                    icon: "dollarsign.circle",
                    title: "No expenses yet",
                    subtitle: "Add your first expense to get started"
                )
            } else {
                ForEach(sortedExpenses) { expense in
                    ModernExpenseRow(expense: expense, group: group)
                }
            }
        }
    }
}

struct ModernExpenseRow: View {
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
        HStack(spacing: 16) {
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: expense.category.icon)
                        .font(.title3)
                        .foregroundColor(categoryColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(expense.paidBy)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Circle()
                        .fill(AppColors.tertiaryText)
                        .frame(width: 3, height: 3)
                    
                    Text(expense.date, style: .date)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
            }
            
            Spacer()
            
            Text(formatCurrency(expense.totalAmount))
                .font(AppFonts.headline)
                .foregroundColor(AppColors.accent)
        }
        .padding(20)
        .modernCard()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = group.currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct ModernBalancesTab: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var balances: [Balance] {
        expenseViewModel.calculateBalances(for: group)
    }
    
    var settlements: [Settlement] {
        expenseViewModel.suggestSettlements(for: group)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Balances section
            VStack(alignment: .leading, spacing: 16) {
                Text("Current Balances")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                if balances.isEmpty {
                    Text("All balanced!")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(balances) { balance in
                        ModernBalanceRow(balance: balance, currency: group.currency)
                    }
                }
            }
            
            // Settlements section
            if !settlements.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Suggested Settlements")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    ForEach(settlements) { settlement in
                        ModernSettlementRow(settlement: settlement, currency: group.currency)
                    }
                }
            }
        }
    }
}

struct ModernBalanceRow: View {
    let balance: Balance
    let currency: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(balance.isPositive ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: balance.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(balance.isPositive ? AppColors.success : AppColors.error)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(balance.participant)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Text(balance.statusDescription)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(balance.formattedAmount)
                .font(AppFonts.headline)
                .foregroundColor(balance.isPositive ? AppColors.success : AppColors.error)
        }
        .padding(20)
        .modernCard()
    }
}

struct ModernSettlementRow: View {
    let settlement: Settlement
    let currency: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundColor(AppColors.accent)
            
            Text("\(settlement.fromParticipant) → \(settlement.toParticipant)")
                .font(AppFonts.bodyMedium)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Text(settlement.formattedAmount)
                .font(AppFonts.headline)
                .foregroundColor(AppColors.accent)
        }
        .padding(20)
        .background(AppColors.accent.opacity(0.05))
        .modernCard()
    }
}

struct ModernStatsTab: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Category breakdown
            VStack(alignment: .leading, spacing: 16) {
                Text("Spending by Category")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    if let expenses = expenseViewModel.expensesByCategory()[category], !expenses.isEmpty {
                        CategoryStatRow(
                            category: category,
                            amount: expenses.reduce(0) { $0 + $1.totalAmount },
                            count: expenses.count,
                            total: expenseViewModel.totalAmount(),
                            currency: group.currency
                        )
                    }
                }
            }
        }
    }
}

struct CategoryStatRow: View {
    let category: ExpenseCategory
    let amount: Double
    let count: Int
    let total: Double
    let currency: String
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return (amount / total) * 100
    }
    
    private var categoryColor: Color {
        switch category {
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
        VStack(spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.body)
                    .foregroundColor(categoryColor)
                
                Text(category.rawValue)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(amount))
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("\(count) expenses")
                        .font(AppFonts.footnote)
                        .foregroundColor(AppColors.tertiaryText)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.tertiaryBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(categoryColor)
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(Int(percentage))%")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                Spacer()
            }
        }
        .padding(20)
        .modernCard()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct ModernEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppColors.tertiaryText)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}