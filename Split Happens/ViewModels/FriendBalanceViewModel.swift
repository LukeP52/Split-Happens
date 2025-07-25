//
//  FriendBalanceViewModel.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FriendBalanceViewModel: ObservableObject {
    @Published var friendBalances: [FriendBalance] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager.shared
    private let expenseCalculator = ExpenseCalculator.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotificationObservers()
    }
    
    // MARK: - Computed Properties
    
    var totalOwed: Double {
        friendBalances.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }
    
    var totalOwe: Double {
        abs(friendBalances.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount })
    }
    
    var netBalance: Double {
        friendBalances.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Data Loading
    
    func loadFriendBalances() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get all groups
            let groups = try await cloudKitManager.fetchGroupsAsModels()
            var allFriendBalances: [String: Double] = [:]
            
            // Calculate balances for each group
            for group in groups {
                let expenses = try await cloudKitManager.fetchExpensesAsModels(for: group.id)
                let balances = expenseCalculator.calculateNetBalances(for: group, expenses: expenses)
                
                // Aggregate balances across all groups
                for balance in balances {
                    let currentBalance = allFriendBalances[balance.participant] ?? 0
                    allFriendBalances[balance.participant] = currentBalance + balance.amount
                }
            }
            
            // Convert to FriendBalance objects and filter out zero balances
            friendBalances = allFriendBalances.compactMap { (name, amount) in
                guard abs(amount) > 0.01 else { return nil } // Filter out negligible amounts
                return FriendBalance(
                    id: name,
                    friendName: name,
                    amount: amount
                )
            }
            
        } catch {
            errorMessage = "Failed to load friend balances: \(error.localizedDescription)"
            ErrorHandler.shared.handle(error) {
                Task { await self.loadFriendBalances() }
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Actions
    
    func settleBalance(with friend: FriendBalance) async {
        // TODO: Implement settlement recording
        // This would create a settlement record and update balances
        print("Settling balance with \(friend.friendName) for \(formatCurrency(abs(friend.amount)))")
    }
    
    func sendReminder(to friend: FriendBalance) async {
        // TODO: Implement reminder system
        // This could send notifications or emails
        print("Sending reminder to \(friend.friendName)")
    }
    
    // MARK: - Helper Methods
    
    func friendsYouOwe() -> [FriendBalance] {
        return friendBalances.filter { $0.amount < 0 }.sorted { abs($0.amount) > abs($1.amount) }
    }
    
    func friendsWhoOweYou() -> [FriendBalance] {
        return friendBalances.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount }
    }
    
    func largestDebt() -> FriendBalance? {
        return friendBalances.min { abs($0.amount) < abs($1.amount) }
    }
    
    func balancesWith(friend: String) -> [GroupBalance] {
        // TODO: Get detailed balance breakdown by group for a specific friend
        return []
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .expensesDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadFriendBalances()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .groupsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadFriendBalances()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Models

