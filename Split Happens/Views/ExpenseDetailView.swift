//
//  ExpenseDetailView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/19/25.
//

import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense
    let group: Group
    @Environment(\.dismiss) private var dismiss
    
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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: expense.category.icon)
                                .font(.system(size: 40))
                                .foregroundColor(categoryColor)
                                .frame(width: 60, height: 60)
                                .background(categoryColor.opacity(0.15))
                                .cornerRadius(16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.description)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Text(expense.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(categoryColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(categoryColor.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                            .background(AppColors.borderColor)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Amount")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                Text(formatCurrency(expense.totalAmount))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.accent)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Date")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                                    .foregroundColor(AppColors.primaryText)
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.cardBackground)
                    .modernCard()
                    
                    // Payment Info Card
                    VStack(spacing: 16) {
                        HStack {
                            Text("Payment Details")
                                .font(.headline)
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Paid by")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                Text(expense.paidBy)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryText)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Split Type")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                Text(expense.splitType.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryText)
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.cardBackground)
                    .modernCard()
                    
                    // Participants Card
                    VStack(spacing: 16) {
                        HStack {
                            Text("Participants (\(expense.participantNames.count))")
                                .font(.headline)
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(expense.participantNames, id: \.self) { participant in
                                HStack {
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundColor(AppColors.accent)
                                    
                                    Text(participant)
                                        .font(.body)
                                        .foregroundColor(AppColors.primaryText)
                                    
                                    Spacer()
                                    
                                    if expense.splitType == .equal {
                                        Text(formatCurrency(expense.equalSplitAmount))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.secondaryText)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppColors.tertiaryBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.cardBackground)
                    .modernCard()
                    
                    // Split Details Card (if not equal split)
                    if expense.splitType != .equal && !expense.customSplits.isEmpty {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Split Breakdown")
                                    .font(.headline)
                                    .foregroundColor(AppColors.primaryText)
                                Spacer()
                            }
                            
                            ForEach(expense.customSplits, id: \.participantID) { split in
                                HStack {
                                    Text(split.participantName)
                                        .font(.body)
                                        .foregroundColor(AppColors.primaryText)
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatCurrency(split.amount))
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.accent)
                                        
                                        if expense.splitType == .percentage {
                                            Text("\(String(format: "%.1f", split.percentage))%")
                                                .font(.caption)
                                                .foregroundColor(AppColors.secondaryText)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppColors.tertiaryBackground)
                                .cornerRadius(8)
                            }
                        }
                        .padding(20)
                        .background(AppColors.cardBackground)
                        .modernCard()
                    }
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        guard amount.isFinite && !amount.isNaN else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = group.currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

#Preview {
    ExpenseDetailView(
        expense: Expense(
            groupReference: "test",
            description: "Dinner at Italian Restaurant",
            totalAmount: 85.50,
            paidBy: "Alice",
            paidByID: "alice-id",
            splitType: .equal,
            date: Date(),
            category: .food,
            participantNames: ["Alice", "Bob", "Charlie"]
        ),
        group: Group(name: "Sample Group", participants: ["Alice", "Bob", "Charlie"])
    )
}