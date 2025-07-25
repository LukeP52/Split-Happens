import SwiftUI

/// Root tab container that mirrors the friend-centric layout we want.
struct MainTabView: View {
    @State private var selectedTab: Int = 1 // default to Groups
    
    // Sheet controllers
    @State private var showingAddExpense = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ModernFriendsView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Friends")
                }
                .tag(0)
            
            ModernGroupListView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Groups")
                }
                .tag(1)
            
            // Center plus tab – selecting immediately triggers modal and resets tab
            Color.clear
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
                .tag(2)
                .onAppear {
                    if selectedTab == 2 {
                        showingAddExpense = true
                    }
                }
            
            ModernActivityView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Activity")
                }
                .tag(3)
            
            ModernAccountView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Account")
                }
                .tag(4)
        }
        .sheet(isPresented: $showingAddExpense, onDismiss: { selectedTab = 1 }) {
            ModernGroupListView()
                .presentationDetents([.large])
        }
    }
}

// MARK: - Placeholder screens

struct ModernFriendsView: View {
    @StateObject private var viewModel = FriendBalanceViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                } else {
                    List {
                        // Header summary
                        if !viewModel.friendBalances.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                if viewModel.totalOwed > 0.01 {
                                    Text("You are owed \(formatCurrency(viewModel.totalOwed)) overall")
                                        .font(AppFonts.title3)
                                        .foregroundColor(AppColors.success)
                                }
                                if viewModel.totalOwe > 0.01 {
                                    Text("You owe \(formatCurrency(viewModel.totalOwe)) overall")
                                        .font(AppFonts.title3)
                                        .foregroundColor(AppColors.error)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        
                        ForEach(viewModel.friendBalances) { balance in
                            MainTabFriendBalanceRow(balance: balance)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount.isFinite ? amount : 0)) ?? "$0.00"
    }
}

struct MainTabFriendBalanceRow: View {
    let balance: FriendBalance
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar initials
            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(balance.friendName.prefix(2).uppercased())
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.accent)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(balance.friendName)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Text(balance.isPositive ? "you owe" : (balance.isNegative ? "owes you" : "settled"))
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(balance.formattedAmount)
                .font(AppFonts.headline)
                .foregroundColor(balance.isPositive ? AppColors.error : (balance.isNegative ? AppColors.success : AppColors.secondaryText))
        }
        .padding(20)
        .modernCard()
    }
}

struct ModernActivityView: View {
    @StateObject private var viewModel = ActivityViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            ActivityRow(item: item)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct ActivityRow: View {
    let item: ActivityItem
    
    private var color: Color { item.amount >= 0 ? AppColors.accent : AppColors.error }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon based on amount sign
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: item.amount >= 0 ? "dollarsign.circle" : "arrow.up.arrow.down")
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.paidBy) added \(item.description)")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Text(item.date, style: .date)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(formatCurrency(item.amount, code: item.currency))
                .font(AppFonts.bodyMedium)
                .foregroundColor(color)
        }
        .padding(20)
        .modernCard()
    }
    
    private func formatCurrency(_ amount: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: amount.isFinite ? amount : 0)) ?? "$0.00"
    }
}

struct ModernAccountView: View {
    @StateObject private var viewModel = AccountViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                List {
                    // Header
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Circle()
                                .fill(viewModel.user.avatarColor.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(viewModel.user.name.prefix(1))
                                        .font(AppFonts.title)
                                        .foregroundColor(viewModel.user.avatarColor)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.user.name)
                                    .font(AppFonts.headline)
                                    .foregroundColor(AppColors.primaryText)
                                Text(viewModel.user.email)
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            Spacer()
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    
                    Section(header: Text("Preferences").foregroundColor(AppColors.secondaryText)) {
                        ModernListRow(icon: "bell", title: "Notifications", showChevron: true)
                        ModernListRow(icon: "lock", title: "Security", showChevron: true)
                    }
                    .listSectionSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    Section(header: Text("Connected Accounts").foregroundColor(AppColors.secondaryText)) {
                        ModernListRow(icon: "creditcard", title: "Bank Connections", subtitle: "Plaid", showChevron: true)
                    }
                    .listSectionSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    Section(header: Text("Feedback").foregroundColor(AppColors.secondaryText)) {
                        ModernListRow(icon: "envelope", title: "Contact Us", showChevron: true)
                        ModernListRow(icon: "star", title: "Rate Split Happens", showChevron: false)
                    }
                    .listSectionSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
} 