//
//  BalancesView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI

struct BalancesTabView: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var balances: [Balance] {
        expenseViewModel.calculateBalances(for: group)
    }
    
    var settlements: [(from: String, to: String, amount: Double)] {
        let settlementObjects = expenseViewModel.suggestSettlements(for: group)
        return settlementObjects.map { settlement in
            (from: settlement.fromParticipant, to: settlement.toParticipant, amount: settlement.amount)
        }
    }
    
    var body: some View {
        List {
            Section("Balances") {
                if balances.isEmpty {
                    Text("No balances to show")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(balances, id: \.participant) { balance in
                        BalanceRowView(balance: balance, currency: group.currency)
                    }
                }
            }
            
            if !settlements.isEmpty {
                Section("Settlement Suggestions") {
                    ForEach(Array(settlements.enumerated()), id: \.offset) { index, settlement in
                        SettlementRowView(settlement: settlement, currency: group.currency)
                    }
                }
            }
        }
    }
}

struct BalanceRowView: View {
    let balance: Balance
    let currency: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(balance.isPositive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: balance.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(balance.isPositive ? .green : .red)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(balance.participant)
                    .font(.headline)
                
                Text(balance.isPositive ? "Owed to you" : "You owe")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(balance.amount, currency: currency))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(balance.isPositive ? .green : .red)
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

struct SettlementRowView: View {
    let settlement: (from: String, to: String, amount: Double)
    let currency: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(settlement.from) → \(settlement.to)")
                    .font(.headline)
                
                Text("Settlement")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(settlement.amount, currency: currency))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

struct SummaryTabView: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var summary: (totalSpent: Double, averagePerPerson: Double, expenseCount: Int) {
        expenseViewModel.calculateGroupSummary(for: group)
    }
    
    var expensesByCategory: [ExpenseCategory: [Expense]] {
        expenseViewModel.expensesByCategory()
    }
    
    var body: some View {
        List {
            Section("Overview") {
                SummaryRowView(
                    title: "Total Spent",
                    value: formatCurrency(summary.totalSpent, currency: group.currency),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                SummaryRowView(
                    title: "Average per Person",
                    value: formatCurrency(summary.averagePerPerson, currency: group.currency),
                    icon: "person.2.fill",
                    color: .blue
                )
                
                SummaryRowView(
                    title: "Total Expenses",
                    value: "\(summary.expenseCount)",
                    icon: "list.bullet",
                    color: .orange
                )
            }
            
            if !expensesByCategory.isEmpty {
                Section("By Category") {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        if let expenses = expensesByCategory[category] {
                            CategorySummaryRowView(
                                category: category,
                                expenses: expenses,
                                currency: group.currency
                            )
                        }
                    }
                }
            }
            
            if !group.participants.isEmpty {
                Section("By Participant") {
                    ForEach(group.participants, id: \.self) { participant in
                        ParticipantSummaryRowView(
                            participant: participant,
                            expenses: expenseViewModel.expensesByParticipant(participant),
                            currency: group.currency
                        )
                    }
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

struct SummaryRowView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

struct CategorySummaryRowView: View {
    let category: ExpenseCategory
    let expenses: [Expense]
    let currency: String
    
    var totalAmount: Double {
        expenses.reduce(0) { total, expense in
            guard expense.totalAmount.isFinite else { return total }
            return total + expense.totalAmount
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.body)
                
                Text("\(expenses.count) expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(totalAmount, currency: currency))
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

struct ParticipantSummaryRowView: View {
    let participant: String
    let expenses: [Expense]
    let currency: String
    
    var totalAmount: Double {
        expenses.reduce(0) { total, expense in
            guard expense.totalAmount.isFinite else { return total }
            return total + expense.totalAmount
        }
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(participant.prefix(1)).uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant)
                    .font(.body)
                
                Text("\(expenses.count) expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(totalAmount, currency: currency))
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

#Preview {
    BalancesTabView(
        group: Group(name: "Sample Group", participants: ["Alice", "Bob", "Charlie"]),
        expenseViewModel: ExpenseViewModel()
    )
} 