//
//  UnifiedExpenseView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import SwiftUI

struct UnifiedExpenseView: View {
    @StateObject private var viewModel = UnifiedExpenseViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: ExpenseCategory?
    
    private var filteredExpenses: [ExpenseWithGroup] {
        if !searchText.isEmpty {
            return viewModel.searchExpenses(query: searchText)
        } else if let category = selectedCategory {
            return viewModel.expenses(for: category)
        } else {
            return viewModel.allExpenses
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                ModernGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Weekly summary card
                        WeeklySummaryCard(
                            totalSpent: viewModel.totalSpentThisWeek,
                            expenseCount: viewModel.recentExpenses.count
                        )
                        .padding(.horizontal, 20)
                        
                        // Recent purchases section
                        if !viewModel.recentExpenses.isEmpty {
                            RecentPurchasesSection(expenses: viewModel.recentExpenses)
                                .padding(.horizontal, 20)
                        }
                        
                        // Category breakdown
                        if !viewModel.topSpendingCategories.isEmpty {
                            CategoryBreakdownSection(
                                categories: viewModel.topSpendingCategories,
                                selectedCategory: $selectedCategory
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Activity feed
                        ActivityFeedSection(
                            activities: viewModel.allActivity,
                            searchText: $searchText
                        )
                        .padding(.horizontal, 20)
                        
                        // Bottom padding
                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 20)
                }
                .searchable(text: $searchText, prompt: "Search expenses...")
                .refreshable {
                    await viewModel.loadAllExpenses()
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .withErrorHandling()
        }
    }
}

// MARK: - Supporting Views

struct WeeklySummaryCard: View {
    let totalSpent: Double
    let expenseCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Text(formatCurrency(totalSpent))
                        .font(AppFonts.numberLarge)
                        .foregroundColor(AppColors.primaryText)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("\(expenseCount)")
                        .font(AppFonts.numberLarge)
                        .foregroundColor(AppColors.accent)
                    Text("Expenses")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(12)
                .background(
                    Circle()
                        .fill(AppColors.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                )
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [AppColors.cardBackgroundElevated, AppColors.cardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .modernCard(isElevated: true)
    }
}

struct RecentPurchasesSection: View {
    let expenses: [ExpenseWithGroup]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Purchases")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full expense list
                }
                .font(AppFonts.caption)
                .foregroundColor(AppColors.accent)
            }
            
            VStack(spacing: 0) {
                ForEach(expenses.prefix(3)) { expenseWithGroup in
                    RecentPurchaseRow(expenseWithGroup: expenseWithGroup)
                    
                    if expenseWithGroup.id != expenses.prefix(3).last?.id {
                        Divider()
                            .background(AppColors.borderColor)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(AppColors.cardBackground)
            .modernCard()
        }
    }
}

struct RecentPurchaseRow: View {
    let expenseWithGroup: ExpenseWithGroup
    
    var body: some View {
        HStack(spacing: 16) {
            // Category icon
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(expenseWithGroup.expense.category.swiftUIColor.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: expenseWithGroup.expense.category.icon)
                        .font(.title3)
                        .foregroundColor(expenseWithGroup.expense.category.swiftUIColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expenseWithGroup.expense.description)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Text("in \(expenseWithGroup.group.name)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(expenseWithGroup.expense.totalAmount.safeValue))
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Text(expenseWithGroup.expense.formattedDate)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(20)
    }
}

struct CategoryBreakdownSection: View {
    let categories: [(category: ExpenseCategory, amount: Double)]
    @Binding var selectedCategory: ExpenseCategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Categories")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.category) { item in
                        CategoryBreakdownChip(
                            category: item.category,
                            amount: item.amount,
                            isSelected: selectedCategory == item.category
                        ) {
                            selectedCategory = selectedCategory == item.category ? nil : item.category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
}

struct CategoryBreakdownChip: View {
    let category: ExpenseCategory
    let amount: Double
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : category.swiftUIColor)
                
                Text(category.displayName)
                    .font(AppFonts.caption)
                    .foregroundColor(isSelected ? .white : AppColors.primaryText)
                
                Text(formatCurrency(amount))
                    .font(AppFonts.captionMedium)
                    .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? category.swiftUIColor : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.clear : AppColors.borderColor,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActivityFeedSection: View {
    let activities: [Activity]
    @Binding var searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            VStack(spacing: 0) {
                ForEach(activities.prefix(10)) { activity in
                    ActivityItemRow(activity: activity)
                    
                    if activity.id != activities.prefix(10).last?.id {
                        Divider()
                            .background(AppColors.borderColor)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(AppColors.cardBackground)
            .modernCard()
        }
    }
}

struct ActivityItemRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 16) {
            // Activity icon
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(activity.type.color.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: activity.type.icon)
                        .font(.title3)
                        .foregroundColor(activity.type.color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Text(activity.subtitle)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedAmount)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Text(activity.formattedDate)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(20)
    }
}

#Preview {
    UnifiedExpenseView()
}