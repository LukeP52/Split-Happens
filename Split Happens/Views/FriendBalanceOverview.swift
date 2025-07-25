//
//  FriendBalanceOverview.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import SwiftUI

struct FriendBalanceOverview: View {
    @StateObject private var viewModel = FriendBalanceViewModel()
    @State private var selectedFriend: FriendBalance?
    @State private var showingSettlement = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                ModernGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Overall balance summary
                        BalanceOverviewCard(
                            totalOwed: viewModel.totalOwed,
                            totalOwe: viewModel.totalOwe,
                            netBalance: viewModel.netBalance
                        )
                        .padding(.horizontal, 20)
                        
                        // Quick actions
                        QuickActionsSection {
                            // Add expense across groups
                        } onSettleUp: {
                            showingSettlement = true
                        }
                        .padding(.horizontal, 20)
                        
                        // Friend balances list
                        if !viewModel.friendBalances.isEmpty {
                            FriendBalancesList(
                                balances: viewModel.friendBalances,
                                onFriendTapped: { friend in
                                    selectedFriend = friend
                                },
                                onSettleWithFriend: { friend in
                                    selectedFriend = friend
                                    showingSettlement = true
                                }
                            )
                            .padding(.horizontal, 20)
                        } else {
                            EmptyBalancesView()
                                .padding(.horizontal, 20)
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 20)
                }
                .refreshable {
                    await viewModel.loadFriendBalances()
                }
            }
            .navigationTitle("Balances")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSettlement) {
                if let friend = selectedFriend {
                    SettlementFlowView(friendBalance: friend)
                }
            }
            .withErrorHandling()
        }
        .task {
            await viewModel.loadFriendBalances()
        }
    }
}

// MARK: - Supporting Views

struct BalanceOverviewCard: View {
    let totalOwed: Double
    let totalOwe: Double
    let netBalance: Double
    
    private var isOwed: Bool {
        netBalance > 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Net balance display
            VStack(spacing: 8) {
                Text(isOwed ? "You are owed" : netBalance < 0 ? "You owe" : "All settled up!")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                Text(formatCurrency(abs(netBalance)))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(
                        netBalance > 0 ? AppColors.success :
                        netBalance < 0 ? AppColors.error :
                        AppColors.primaryText
                    )
            }
            
            // Breakdown
            HStack(spacing: 20) {
                BalanceSummaryCard(
                    title: "You are owed",
                    amount: totalOwed,
                    color: AppColors.success
                )
                
                BalanceSummaryCard(
                    title: "You owe",
                    amount: totalOwe,
                    color: AppColors.error
                )
            }
        }
        .padding(24)
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

struct BalanceSummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
            
            Text(formatCurrency(amount))
                .font(AppFonts.numberMedium)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct QuickActionsSection: View {
    let onAddExpense: () -> Void
    let onSettleUp: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAddExpense) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Expense")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(AppColors.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: onSettleUp) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.title3)
                    Text("Settle Up")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(AppColors.cardBackground)
                .foregroundColor(AppColors.accent)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent, lineWidth: 2)
                )
            }
        }
    }
}

struct FriendBalancesList: View {
    let balances: [FriendBalance]
    let onFriendTapped: (FriendBalance) -> Void
    let onSettleWithFriend: (FriendBalance) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friend Balances")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            VStack(spacing: 0) {
                ForEach(balances.sorted { abs($0.amount) > abs($1.amount) }) { balance in
                    FriendBalanceRow(
                        balance: balance,
                        onTapped: { onFriendTapped(balance) },
                        onSettle: { onSettleWithFriend(balance) }
                    )
                    
                    if balance.id != balances.last?.id {
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

struct FriendBalanceRow: View {
    let balance: FriendBalance
    let onTapped: () -> Void
    let onSettle: () -> Void
    
    private var isOwed: Bool {
        balance.amount > 0
    }
    
    var body: some View {
        Button(action: onTapped) {
            HStack(spacing: 16) {
                // Friend avatar
                PersonAvatar(name: balance.friendName, size: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(balance.friendName)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(isOwed ? "owes you" : "you owe")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(abs(balance.amount)))
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(isOwed ? AppColors.success : AppColors.error)
                        .fontWeight(.semibold)
                    
                    if abs(balance.amount) > 0 {
                        Button("Settle") {
                            onSettle()
                        }
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.accent)
                    }
                }
            }
            .padding(20)
        }
        .buttonStyle(.plain)
    }
}

struct PersonAvatar: View {
    let name: String
    let size: CGFloat
    
    private var initials: String {
        let components = name.components(separatedBy: " ")
        let firstInitial = components.first?.first?.uppercased() ?? ""
        let lastInitial = components.count > 1 ? components.last?.first?.uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
    
    private var backgroundColor: Color {
        // Generate consistent color based on name
        let hash = name.hashValue
        let colors: [Color] = [
            AppColors.accent,
            AppColors.accentSecondary,
            AppColors.success,
            AppColors.warning,
            .blue,
            .purple,
            .pink,
            .orange
        ]
        return colors[abs(hash) % colors.count]
    }
    
    var body: some View {
        Circle()
            .fill(backgroundColor.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(backgroundColor)
            )
    }
}

struct EmptyBalancesView: View {
    var body: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(AppColors.accent.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accent)
                )
            
            VStack(spacing: 8) {
                Text("No balances yet")
                    .font(AppFonts.title3)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Add some expenses with friends to see balances here")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .modernCard()
    }
}

#Preview {
    FriendBalanceOverview()
}