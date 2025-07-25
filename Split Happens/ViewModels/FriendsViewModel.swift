import Foundation
import SwiftUI
import Combine

struct FriendBalance: Identifiable {
    let id = UUID()
    let friendName: String
    var amount: Double // positive = they owe you, negative = you owe them
    let currency: String
    
    var isPositive: Bool { amount > 0.01 }
    var isNegative: Bool { amount < -0.01 }
    var isSettled: Bool { abs(amount) < 0.01 }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let safeValue = amount.isFinite ? abs(amount) : 0
        return formatter.string(from: NSNumber(value: safeValue)) ?? "$0.00"
    }
}

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friendBalances: [FriendBalance] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let groupVM: GroupViewModel = GroupViewModel.shared ?? GroupViewModel()
    private let cloudKit = CloudKitManager.shared
    private let calculator = ExpenseCalculator.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        observeGroupChanges()
        Task { await reloadBalances() }
    }
    
    private func observeGroupChanges() {
        NotificationCenter.default.publisher(for: .groupsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.reloadBalances() }
            }
            .store(in: &cancellables)
    }
    
    func reloadBalances() async {
        isLoading = true
        errorMessage = nil
        
        var aggregate: [String: (amount: Double, currency: String)] = [:]
        do {
            let groups = groupVM.groups
            for group in groups {
                // Fetch expenses for each group
                let expenses = try await cloudKit.fetchExpensesAsModels(for: group.id)
                let balances = calculator.calculateNetBalances(for: group, expenses: expenses)
                for b in balances {
                    aggregate[b.participant, default: (0, group.currency)].amount += b.amount
                }
            }
            // Map to FriendBalance, exclude current user later
            friendBalances = aggregate.map { key, tuple in
                FriendBalance(friendName: key, amount: tuple.amount, currency: tuple.currency)
            }.sorted { abs($0.amount) > abs($1.amount) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    var totalPositive: Double {
        friendBalances.filter { $0.isPositive }.reduce(0) { $0 + $1.amount }
    }
    var totalNegative: Double {
        friendBalances.filter { $0.isNegative }.reduce(0) { $0 + $1.amount }
    }
} 