// ModernGroupListView.swift
import SwiftUI

struct ModernGroupListView: View {
    @StateObject private var groupViewModel = GroupViewModel()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var offlineManager = OfflineStorageManager.shared
    @State private var showingCreateGroup = false
    @State private var isLoadingGroups = false
    
    var filteredGroups: [Group] {
        groupViewModel.groups.filter { $0.isActive }
    }
    
    var totalBalance: Double {
        filteredGroups.reduce(0) { $0 + $1.totalSpent.safeValue }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background - fixed position
                ModernGradientBackground()
                    .ignoresSafeArea()
                
                List {
                    // Header with balance
                    headerSection
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                    // Groups list
                    ForEach(filteredGroups) { group in
                        NavigationLink(destination: ModernGroupDetailView(group: group)) {
                            ModernGroupCard(group: group)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await groupViewModel.deleteGroup(group)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    if filteredGroups.isEmpty {
                        EmptyStateCard()
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    }
                    
                    // Spacer for bottom padding
                    Color.clear
                        .frame(height: 80)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, 20)
            }
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                // Floating action button
                CircularIconButton(
                    icon: "plus",
                    size: 56,
                    action: { showingCreateGroup = true }
                )
                .padding(.trailing, 24)
                .padding(.bottom, 40)
                .shadow(color: AppColors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .sheet(isPresented: $showingCreateGroup) {
                ModernCreateGroupView(groupViewModel: groupViewModel)
            }
            .task {
                await loadGroupsOfflineFirst()
                groupViewModel.startPeriodicSync()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // App title and profile
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Split Happens")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("\(filteredGroups.count) active groups")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                // Profile button
                Button(action: {}) {
                    Circle()
                        .fill(AppColors.tertiaryBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(AppColors.accent)
                        )
                }
            }
            
            // Total balance card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Expenses")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text(formatCurrency(totalBalance))
                            .font(AppFonts.numberLarge)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Spacer()
                    
                    // Active groups indicator
                    VStack(spacing: 4) {
                        Text("\(filteredGroups.filter { $0.totalSpent > 0 }.count)")
                            .font(AppFonts.numberLarge)
                            .foregroundColor(AppColors.accent)
                        Text("Active")
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
        .padding(.horizontal, 20)
    }
    
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func loadGroupsOfflineFirst() async {
        guard !isLoadingGroups else { return }
        isLoadingGroups = true
        
        // Load from cache immediately
        let cachedGroups = offlineManager.loadGroups()
        if !cachedGroups.isEmpty {
            await MainActor.run {
                groupViewModel.groups = cachedGroups
            }
        }
        
        // Try to sync in background
        if offlineManager.isOnline {
            await groupViewModel.loadGroups()
        }
        
        isLoadingGroups = false
    }
    
}

// MARK: - Components


struct ModernGroupCard: View {
    let group: Group
    
    var body: some View {
        HStack(spacing: 16) {
            // Group icon or image
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.3), AppColors.accentSecondary.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                )
            
            // Group info
            HStack {
                Text(group.name)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                Text(group.formattedTotalSpent)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
            }
        }
        .padding(20)
        .modernCard()
    }
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(AppColors.accent.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accent)
                )
            
            VStack(spacing: 8) {
                Text("No groups yet")
                    .font(AppFonts.title3)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Create your first group to start splitting expenses")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .modernCard()
    }
}