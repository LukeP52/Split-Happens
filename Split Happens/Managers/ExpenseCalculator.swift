//
//  ExpenseCalculator.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation

// MARK: - Data Structures

struct Balance: Identifiable, Equatable {
    let id = UUID()
    let participant: String
    let participantID: String
    var amount: Double
    let currency: String
    
    var isPositive: Bool {
        amount > 0.01
    }
    
    var isNegative: Bool {
        amount < -0.01
    }
    
    var isSettled: Bool {
        abs(amount) < 0.01
    }
    
    var formattedAmount: String {
        formatCurrency(abs(amount), currency: currency)
    }
    
    var signedFormattedAmount: String {
        let sign = amount > 0.01 ? "+" : (amount < -0.01 ? "-" : "")
        return "\(sign)\(formattedAmount)"
    }
    
    var statusDescription: String {
        if isSettled {
            return "Settled"
        } else if isPositive {
            return "Should receive"
        } else {
            return "Should pay"
        }
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

struct Settlement: Identifiable, Equatable {
    let id = UUID()
    let fromParticipant: String
    let fromParticipantID: String
    let toParticipant: String
    let toParticipantID: String
    let amount: Double
    let currency: String
    var isCompleted: Bool = false
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
    
    var description: String {
        "\(fromParticipant) owes \(toParticipant) \(formattedAmount)"
    }
}

struct ParticipantBalance: Identifiable {
    let id = UUID()
    let participant: String
    let participantID: String
    var totalPaid: Double = 0.0
    var totalOwed: Double = 0.0
    let currency: String
    
    var netBalance: Double {
        totalPaid - totalOwed
    }
    
    var isPositive: Bool {
        netBalance > 0.01
    }
    
    var isNegative: Bool {
        netBalance < -0.01
    }
    
    var isSettled: Bool {
        abs(netBalance) < 0.01
    }
    
    var formattedTotalPaid: String {
        formatCurrency(totalPaid)
    }
    
    var formattedTotalOwed: String {
        formatCurrency(totalOwed)
    }
    
    var formattedNetBalance: String {
        formatCurrency(abs(netBalance))
    }
    
    var signedFormattedNetBalance: String {
        let sign = netBalance > 0.01 ? "+" : (netBalance < -0.01 ? "-" : "")
        return "\(sign)\(formattedNetBalance)"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

// MARK: - Expense Calculator

@MainActor
class ExpenseCalculator: ObservableObject {
    static let shared = ExpenseCalculator()
    
    private init() {}
    
    // MARK: - Main Balance Calculation
    
    func calculateNetBalances(for group: Group, expenses: [Expense]) -> [Balance] {
        var participantBalances: [String: ParticipantBalance] = [:]
        
        // Guard: no participants
        guard !group.participants.isEmpty else { return [] }

        // Initialize balances for all participants
        for (index, participant) in group.participants.enumerated() {
            let participantID = index < group.participantIDs.count ? group.participantIDs[index] : UUID().uuidString
            participantBalances[participant] = ParticipantBalance(
                participant: participant,
                participantID: participantID,
                currency: group.currency
            )
        }
        
        // Process each expense
        for expense in expenses {
            processExpense(expense, participantBalances: &participantBalances, group: group)
        }
        
        // Convert to Balance objects
        return participantBalances.values.map { participantBalance in
            Balance(
                participant: participantBalance.participant,
                participantID: participantBalance.participantID,
                amount: participantBalance.netBalance,
                currency: group.currency
            )
        }.sorted { abs($0.amount) > abs($1.amount) }
    }
    
    private func processExpense(_ expense: Expense, participantBalances: inout [String: ParticipantBalance], group: Group) {
        // Add payment to the person who paid
        if var payer = participantBalances[expense.paidBy] {
            payer.totalPaid += expense.totalAmount
            participantBalances[expense.paidBy] = payer
        }
        
        // Calculate split amounts; if model contains no split info, assume equal split among the group's participants
        var splitAmounts = expense.calculateSplitAmounts()
        if splitAmounts.isEmpty {
            let perPerson = NaNDetector.shared.validate(expense.totalAmount / Double(max(group.participants.count, 1)), context: "ExpenseCalculator.processExpense.fallbackEqual")
            for participant in group.participants {
                splitAmounts[participant] = perPerson
            }
        }
        // Ensure rounding error does not leave unmatched cents
        let owedSum = splitAmounts.values.reduce(0, +)
        let diff    = expense.totalAmount - owedSum
        if abs(diff) > 0.01, let first = group.participants.first {
            splitAmounts[first, default: 0] += diff // push residual onto first participant
        }
        // Subtract what each participant owes
        for (participant, owedAmount) in splitAmounts {
            if var participantBalance = participantBalances[participant] {
                participantBalance.totalOwed += owedAmount
                participantBalances[participant] = participantBalance
            }
        }
    }
    
    // MARK: - Debt Simplification Algorithm
    
    func simplifyDebts(balances: [Balance]) -> [Settlement] {
        guard !balances.isEmpty else { return [] }
        
        // Filter out settled balances and separate creditors from debtors
        let activeBalances = balances.filter { !$0.isSettled }
        var creditors = activeBalances.filter { $0.isPositive }.sorted { $0.amount > $1.amount }
        var debtors = activeBalances.filter { $0.isNegative }.sorted { $0.amount < $1.amount }
        
        var settlements: [Settlement] = []
        
        // Use greedy algorithm to minimize number of transactions
        while !creditors.isEmpty && !debtors.isEmpty {
            let creditor = creditors[0]
            let debtor = debtors[0]
            
            // Calculate settlement amount
            let settlementAmount = min(creditor.amount, abs(debtor.amount))
            
            if settlementAmount > 0.01 {
                let settlement = Settlement(
                    fromParticipant: debtor.participant,
                    fromParticipantID: debtor.participantID,
                    toParticipant: creditor.participant,
                    toParticipantID: creditor.participantID,
                    amount: settlementAmount,
                    currency: creditor.currency
                )
                settlements.append(settlement)
            }
            
            // Update remaining amounts
            let remainingCreditorAmount = creditor.amount - settlementAmount
            let remainingDebtorAmount = debtor.amount + settlementAmount
            
            // Remove or update creditor
            if remainingCreditorAmount < 0.01 {
                creditors.removeFirst()
            } else {
                creditors[0] = Balance(
                    participant: creditor.participant,
                    participantID: creditor.participantID,
                    amount: remainingCreditorAmount,
                    currency: creditor.currency
                )
            }
            
            // Remove or update debtor
            if remainingDebtorAmount > -0.01 {
                debtors.removeFirst()
            } else {
                debtors[0] = Balance(
                    participant: debtor.participant,
                    participantID: debtor.participantID,
                    amount: remainingDebtorAmount,
                    currency: debtor.currency
                )
            }
        }
        
        return settlements
    }
    
    // MARK: - Advanced Debt Optimization
    
    func optimizeSettlements(balances: [Balance]) -> [Settlement] {
        // Try multiple algorithms and return the one with fewest transactions
        let greedySettlements = simplifyDebts(balances: balances)
        let optimizedSettlements = tryOptimizedAlgorithm(balances: balances)
        
        // Return the solution with fewer transactions
        return greedySettlements.count <= optimizedSettlements.count ? greedySettlements : optimizedSettlements
    }
    
    private func tryOptimizedAlgorithm(balances: [Balance]) -> [Settlement] {
        // Implementation of more sophisticated algorithm (e.g., minimum cost flow)
        // For now, return the greedy result
        return simplifyDebts(balances: balances)
    }
    
    // MARK: - Individual Calculations
    
    func calculateParticipantBalances(for group: Group, expenses: [Expense]) -> [ParticipantBalance] {
        var participantBalances: [String: ParticipantBalance] = [:]
        
        // Initialize balances
        for (index, participant) in group.participants.enumerated() {
            let participantID = index < group.participantIDs.count ? group.participantIDs[index] : UUID().uuidString
            participantBalances[participant] = ParticipantBalance(
                participant: participant,
                participantID: participantID,
                currency: group.currency
            )
        }
        
        // Process expenses
        for expense in expenses {
            // Add payment
            if var payer = participantBalances[expense.paidBy] {
                payer.totalPaid += expense.totalAmount
                participantBalances[expense.paidBy] = payer
            }
            
            // Add owed amounts
            let splitAmounts = expense.calculateSplitAmounts()
            for (participant, owedAmount) in splitAmounts {
                if var participantBalance = participantBalances[participant] {
                    participantBalance.totalOwed += owedAmount
                    participantBalances[participant] = participantBalance
                }
            }
        }
        
        return Array(participantBalances.values).sorted { $0.participant < $1.participant }
    }
    
    // MARK: - Expense Analysis
    
    func analyzeExpenseDistribution(expenses: [Expense], participants: [String]) -> [String: Double] {
        var distribution: [String: Double] = [:]
        
        for participant in participants {
            distribution[participant] = 0.0
        }
        
        for expense in expenses {
            let splitAmounts = expense.calculateSplitAmounts()
            for (participant, amount) in splitAmounts {
                distribution[participant, default: 0.0] += amount
            }
        }
        
        return distribution
    }
    
    func calculateCategoryTotals(expenses: [Expense]) -> [ExpenseCategory: Double] {
        var categoryTotals: [ExpenseCategory: Double] = [:]
        
        for expense in expenses {
            categoryTotals[expense.category, default: 0.0] += expense.totalAmount
        }
        
        return categoryTotals
    }
    
    // MARK: - Currency Handling
    
    func convertAmount(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) -> Double {
        // In a real app, you would integrate with a currency conversion API
        // For now, return the original amount (assuming same currency)
        if sourceCurrency == targetCurrency {
            return amount
        }
        
        // Placeholder conversion rates (in a real app, fetch from API)
        let conversionRates: [String: [String: Double]] = [
            "USD": ["EUR": 0.85, "GBP": 0.73, "CAD": 1.25, "AUD": 1.35],
            "EUR": ["USD": 1.18, "GBP": 0.86, "CAD": 1.47, "AUD": 1.59],
            "GBP": ["USD": 1.37, "EUR": 1.16, "CAD": 1.71, "AUD": 1.85]
        ]
        
        return conversionRates[sourceCurrency]?[targetCurrency].map { $0 * amount } ?? amount
    }
    
    func formatCurrency(_ amount: Double, currency: String = "USD") -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
    
    // MARK: - Summary Statistics
    
    func calculateGroupSummary(for group: Group, expenses: [Expense]) -> (totalSpent: Double, averagePerPerson: Double, expenseCount: Int, totalTransactions: Int) {
        // Guard against empty expenses
        guard !expenses.isEmpty else {
            return (0, 0, 0, 0)
        }
        
        let totalSpent = expenses.reduce(0) { total, expense in
            guard expense.totalAmount.isFinite && expense.totalAmount >= 0 else { return total }
            return total + expense.totalAmount
        }
        
        // Guard against division by zero
        let averagePerPerson: Double
        if group.participantCount > 0 && totalSpent > 0 {
            averagePerPerson = NaNDetector.shared.validate(totalSpent / Double(group.participantCount), context: "ExpenseCalculator.calculateGroupSummary.averagePerPerson")
        } else {
            averagePerPerson = 0
        }
        
        let expenseCount = expenses.count
        
        // Calculate number of transactions needed
        let balances = calculateNetBalances(for: group, expenses: expenses)
        let settlements = simplifyDebts(balances: balances)
        let totalTransactions = settlements.count
        
        return (totalSpent, averagePerPerson.isFinite ? averagePerPerson : 0, expenseCount, totalTransactions)
    }
    
    // MARK: - Validation
    
    func validateBalances(_ balances: [Balance]) -> Bool {
        let totalBalance = balances.reduce(0) { total, balance in
            guard balance.amount.isFinite else { return total }
            return total + balance.amount
        }
        return abs(totalBalance) < 0.01 // Should sum to approximately zero
    }
    
    func validateSettlements(_ settlements: [Settlement], originalBalances: [Balance]) -> Bool {
        // Create a copy of balances to simulate settlements
        var testBalances: [String: Double] = [:]
        
        for balance in originalBalances {
            testBalances[balance.participant] = balance.amount
        }
        
        // Apply settlements
        for settlement in settlements {
            testBalances[settlement.fromParticipant, default: 0.0] += settlement.amount
            testBalances[settlement.toParticipant, default: 0.0] -= settlement.amount
        }
        
        // Check if all balances are settled
        return testBalances.values.allSatisfy { abs($0) < 0.01 }
    }
} 