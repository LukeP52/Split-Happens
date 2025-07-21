//
//  GroupListView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI
import CloudKit

struct GroupListView: View {
    @StateObject private var groupViewModel = GroupViewModel()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var offlineManager = OfflineStorageManager.shared
    @StateObject private var alertManager = AlertManager.shared
    @State private var showingCreateGroup = false
    @State private var searchText = ""
    
    var filteredGroups: [Group] {
        let activeGroups = groupViewModel.groups.filter { $0.isActive }
        if searchText.isEmpty {
            return activeGroups.sorted { $0.lastActivity > $1.lastActivity }
        } else {
            return activeGroups.filter { group in
                group.name.localizedCaseInsensitiveContains(searchText) ||
                group.participants.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }.sorted { $0.lastActivity > $1.lastActivity }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if !cloudKitManager.isSignedInToiCloud {
                    iCloudUnavailableView
                } else {
                    groupListContent
                }
            }
            .onAppear {
                Task {
                    // Load from local cache first for offline-first approach
                    await loadGroupsOfflineFirst()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var iCloudUnavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 60))
                .foregroundColor(AppColors.error)
            
            Text("iCloud Unavailable")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText)
            
            Text("Please sign in to iCloud in Settings to use Split Happens")
                .font(.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let errorMessage = cloudKitManager.error {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(AppColors.error)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
    
    private var groupListContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredGroups.isEmpty {
                    EmptyStateView(searchText: searchText)
                        .padding(.top, 100)
                } else {
                    ForEach(filteredGroups) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupRowViewWithSync(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(AppColors.background)
        .navigationTitle("Split Happens")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search groups...")
        .refreshable {
            await refreshGroupsOfflineFirst()
        }
        // Floating Add Button
        .overlay(alignment: .bottomTrailing) {
            IconCircleButton("plus") {
                showingCreateGroup = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView(groupViewModel: groupViewModel, offlineManager: offlineManager)
        }
        .onReceive(groupViewModel.$errorMessage) { errorMessage in
            guard let message = errorMessage else { return }
            Task { @MainActor in
                alertManager.showGroupError(message)
                groupViewModel.clearError()
            }
        }
    }
    
    // MARK: - Offline-First Methods
    
    private func loadGroupsOfflineFirst() async {
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
    }
    
    private func refreshGroupsOfflineFirst() async {
        if offlineManager.isOnline {
            await offlineManager.forceSyncNow()
            await groupViewModel.loadGroups()
        } else {
            // Just reload from cache when offline
            let cachedGroups = offlineManager.loadGroups()
            await MainActor.run {
                groupViewModel.groups = cachedGroups
            }
        }
    }
    
    private func archiveGroupOfflineFirst(_ group: Group) async {
        var updatedGroup = group
        updatedGroup.deactivate()
        
        if offlineManager.isOnline {
            await groupViewModel.updateGroup(updatedGroup)
        } else {
            offlineManager.saveGroupOffline(updatedGroup)
            await MainActor.run {
                if let index = groupViewModel.groups.firstIndex(where: { $0.id == group.id }) {
                    groupViewModel.groups[index] = updatedGroup
                }
            }
        }
    }
    
    private func deleteGroupOfflineFirst(_ group: Group) async {
        if offlineManager.isOnline {
            await groupViewModel.deleteGroup(group)
        } else {
            offlineManager.deleteGroupOffline(group)
            await MainActor.run {
                groupViewModel.groups.removeAll { $0.id == group.id }
            }
        }
    }
}

struct LoadingRow: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading groups...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
}

struct EmptyStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(AppColors.tertiaryText)
            
            Text(searchText.isEmpty ? "No Groups Yet" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText)
            
            Text(searchText.isEmpty ? 
                "Create your first expense group to get started" :
                "Try adjusting your search terms")
                .font(.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity) // Remove maxHeight
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 40, leading: 20, bottom: 40, trailing: 20))
    }
}

struct GroupRowView: View {
    let group: Group
    
    private var safeAverageSpent: Double {
        guard group.participantCount > 0 else {
            print("⚠️ NaN Prevention: Group '\(group.name)' has 0 participants")
            return 0
        }
        guard group.totalSpent > 0 else {
            print("⚠️ NaN Prevention: Group '\(group.name)' has 0 totalSpent")
            return 0
        }
        guard group.totalSpent.isFinite else {
            print("⚠️ NaN Prevention: Group '\(group.name)' has non-finite totalSpent: \(group.totalSpent)")
            return 0
        }
        let avg = group.totalSpent / Double(group.participantCount)
        if !avg.isFinite {
            print("⚠️ NaN Prevention: Group '\(group.name)' calculated non-finite average: \(avg)")
            return 0
        }
        return avg
    }
    
    private var shouldShowAverage: Bool {
        group.totalSpent > 0 && group.participantCount > 0 && safeAverageSpent.isFinite
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(AppFonts.title3)
                    .primaryText()
                
                Text("\(group.participantCount) participants")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(group.formattedTotalSpent)
                    .font(AppFonts.title3)
                    .accentText()
                
                Text(group.lastActivity.formatted(date: .abbreviated, time: .omitted))
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AppColors.cardBackground)
        .elegantCard()
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let safeAmount = amount.isFinite ? amount : 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: safeAmount)) ?? "$0.00"
    }
}

struct ParticipantChip: View {
    let name: String
    let style: ChipStyle
    
    enum ChipStyle {
        case primary, secondary
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue.opacity(0.15)
            case .secondary: return .gray.opacity(0.15)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .gray
            }
        }
    }
    
    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(12)
    }
}

struct GroupRowViewWithSync: View {
    let group: Group
    
    var body: some View {
        GroupRowView(group: group)
    }
}

struct CreateGroupView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    @ObservedObject var offlineManager: OfflineStorageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var participants: [String] = []
    @State private var newParticipant = ""
    @State private var selectedCurrency = "USD"
    @State private var isCreating = false
    
    let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "CNY"]
    
    private var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        participants.count >= 2
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Group Name", text: $groupName)
                        .elegantTextField()
                    
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(AppColors.primaryText)
                } header: {
                    Text("Group Details")
                        .foregroundColor(AppColors.secondaryText)
                } footer: {
                    Text("Choose the currency for this expense group")
                        .font(.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
                
                Section {
                    HStack {
                        TextField("Add participant name", text: $newParticipant)
                            .elegantTextField()
                            .onSubmit {
                                addParticipant()
                            }
                        
                        Button("Add", action: addParticipant)
                            .foregroundColor(AppColors.accent)
                            .disabled(newParticipant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                     participants.contains(newParticipant.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                    
                    if participants.isEmpty {
                        Text("Add at least 2 participants")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .italic()
                    } else {
                        ForEach(participants, id: \.self) { participant in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppColors.accent)
                                Text(participant)
                                    .foregroundColor(AppColors.primaryText)
                                Spacer()
                                Button {
                                    participants.removeAll { $0 == participant }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(AppColors.error)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Participants (\(participants.count))")
                        .foregroundColor(AppColors.secondaryText)
                } footer: {
                    Text("Each person who will share expenses in this group")
                        .font(.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
                
                if !isFormValid {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            if groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Label("Group name is required", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            
                            if participants.count < 2 {
                                Label("At least 2 participants required", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .foregroundColor(AppColors.accent)
                    .disabled(!isFormValid || isCreating)
                }
            }
        }
    }
    
    private func addParticipant() {
        let trimmedName = newParticipant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !participants.contains(trimmedName) else { return }
        
        participants.append(trimmedName)
        newParticipant = ""
    }
    
    private func createGroup() {
        guard isFormValid else { return }
        
        isCreating = true
        Task {
            let group = Group(
                name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                participants: participants,
                currency: selectedCurrency
            )
            
            if offlineManager.isOnline {
                await groupViewModel.createGroup(
                    name: group.name,
                    participants: group.participants,
                    currency: group.currency
                )
            } else {
                // Save offline and queue for sync
                offlineManager.saveGroupOffline(group)
                await MainActor.run {
                    groupViewModel.groups.append(group)
                }
            }
            
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

#Preview {
    GroupListView()
} 
