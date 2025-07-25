//
//  GroupViewModel.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class GroupViewModel: ObservableObject {
    static var shared: GroupViewModel?
    
    @Published var groups: [Group] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Self.shared = self
        setupNotificationObservers()
        Task {
            await loadGroups()
            // Clean up any test groups on startup
            await cleanupDeletedGroups()
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .groupsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshGroupsFromNotification()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .dataDidRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshGroupsFromNotification()
            }
            .store(in: &cancellables)
    }
    
    private func refreshGroupsFromNotification() {
        Task {
            await loadGroups()
        }
    }
    
    // MARK: - Group Operations
    
    func loadGroups() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedGroups = try await cloudKitManager.fetchGroupsAsModels()
            // Deduplicate groups by ID and name+participants
            groups = deduplicateGroups(fetchedGroups)
        } catch {
            errorMessage = "Failed to load groups: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createGroup(name: String, participants: [String], currency: String = "USD") async {
        isLoading = true
        errorMessage = nil
        
        // Check for local duplicates first
        if let existingGroup = findDuplicateGroup(name: name, participants: participants) {
            print("⚠️ Found local duplicate group: \(existingGroup.name)")
            errorMessage = "A group with this name and participants already exists"
            isLoading = false
            return
        }
        
        let newGroup = Group(
            name: name,
            participants: participants,
            participantIDs: participants.map { _ in UUID().uuidString },
            currency: currency
        )
        
        do {
            let savedGroup = try await cloudKitManager.saveGroup(newGroup)
            // Check if group already exists in local array before adding
            if !groups.contains(where: { $0.id == savedGroup.id }) {
                groups.append(savedGroup)
            } else {
                // Update existing group if found
                if let index = groups.firstIndex(where: { $0.id == savedGroup.id }) {
                    groups[index] = savedGroup
                }
            }
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateGroup(_ group: Group) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedGroup = try await cloudKitManager.saveGroup(group)
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                groups[index] = updatedGroup
            }
        } catch {
            errorMessage = "Failed to update group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func deleteGroup(_ group: Group) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let record = group.toCKRecord()
            try await cloudKitManager.deleteGroup(record)
            
            // Remove from local array
            await MainActor.run {
                groups.removeAll { $0.id == group.id }
            }
        } catch {
            errorMessage = "Failed to delete group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // Add periodic sync to catch deletions
    func startPeriodicSync() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.syncWithCloudKit()
            }
        }
    }
    
    private func syncWithCloudKit() async {
        do {
            try await cloudKitManager.syncDeletedGroups()
            await loadGroups()
        } catch {
            print("❌ Periodic sync failed: \(error)")
        }
    }
    
    func addParticipant(to group: Group, participant: String) async {
        var updatedGroup = group
        updatedGroup.addParticipant(participant, id: UUID().uuidString)
        await updateGroup(updatedGroup)
    }
    
    func removeParticipant(from group: Group, participant: String) async {
        var updatedGroup = group
        updatedGroup.removeParticipant(participant)
        await updateGroup(updatedGroup)
    }
    
    // MARK: - Helper Methods
    
    func group(with id: String) -> Group? {
        return groups.first { $0.id == id }
    }
    
    func activeGroups() -> [Group] {
        return groups.filter { $0.isActive }
    }
    
    func sortedGroups() -> [Group] {
        return groups.sorted { $0.lastActivity > $1.lastActivity }
    }
    
    // MARK: - Deduplication
    
    private func findDuplicateGroup(name: String, participants: [String]) -> Group? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for group in groups {
            // Check if name matches
            if group.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedName.lowercased() {
                // Check participant overlap (75% or more indicates duplicate)
                let participantSet1 = Set(group.participants.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
                let participantSet2 = Set(participants.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
                
                let intersection = participantSet1.intersection(participantSet2)
                let union = participantSet1.union(participantSet2)
                
                if !union.isEmpty {
                    let overlapPercentage = Double(intersection.count) / Double(union.count)
                    if overlapPercentage >= 0.75 {
                        return group
                    }
                }
            }
        }
        
        return nil
    }
    
    private func deduplicateGroups(_ groups: [Group]) -> [Group] {
        var uniqueGroups: [Group] = []
        var seenIdentifiers: Set<String> = Set()
        var seenGroupHashes: Set<String> = Set()
        
        for group in groups {
            // First check by ID
            if seenIdentifiers.contains(group.id) {
                continue
            }
            
            // Then check by content hash (name + participants)
            let contentHash = createGroupHash(group)
            if seenGroupHashes.contains(contentHash) {
                continue
            }
            
            // Check for similar groups with different IDs
            if let existingGroup = findSimilarGroup(group, in: uniqueGroups) {
                // Merge groups - keep the one with more recent activity
                if group.lastActivity > existingGroup.lastActivity {
                    // Replace existing with newer group
                    if let index = uniqueGroups.firstIndex(where: { $0.id == existingGroup.id }) {
                        uniqueGroups[index] = group
                        seenIdentifiers.insert(group.id)
                        seenGroupHashes.insert(contentHash)
                    }
                }
                // Otherwise keep existing group
                continue
            }
            
            uniqueGroups.append(group)
            seenIdentifiers.insert(group.id)
            seenGroupHashes.insert(contentHash)
        }
        
        print("🔍 Deduplicated \(groups.count) groups to \(uniqueGroups.count) unique groups")
        return uniqueGroups
    }
    
    private func createGroupHash(_ group: Group) -> String {
        let participants = group.participants.sorted().joined(separator: "|")
        return "\\(group.name.lowercased())_\\(participants.lowercased())"
    }
    
    private func findSimilarGroup(_ group: Group, in groups: [Group]) -> Group? {
        for existingGroup in groups {
            if existingGroup.id == group.id {
                continue
            }
            
            // Check name similarity
            let namesSimilar = existingGroup.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == 
                              group.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if namesSimilar {
                // Check participant overlap
                let participantSet1 = Set(existingGroup.participants.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
                let participantSet2 = Set(group.participants.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
                
                let intersection = participantSet1.intersection(participantSet2)
                let union = participantSet1.union(participantSet2)
                
                if !union.isEmpty {
                    let overlapPercentage = Double(intersection.count) / Double(union.count)
                    if overlapPercentage >= 0.8 { // 80% overlap indicates likely duplicate
                        return existingGroup
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Group Total Recalculation
    
    func recalculateAllGroupTotals() async {
        for group in groups {
            do {
                let expenses = try await cloudKitManager.fetchExpensesAsModels(for: group.id)
                let newTotal = expenses.reduce(0) { $0 + $1.totalAmount.safeValue }
                
                if abs(group.totalSpent - newTotal) > 0.01 {
                    var updatedGroup = group
                    updatedGroup.totalSpent = newTotal
                    
                    let savedGroup = try await cloudKitManager.saveGroup(updatedGroup)
                    
                    if let index = groups.firstIndex(where: { $0.id == group.id }) {
                        await MainActor.run {
                            groups[index] = savedGroup
                        }
                    }
                }
            } catch {
                print("Failed to recalculate total for group \(group.id): \(error)")
            }
        }
    }
    
    // MARK: - Manual Cleanup
    
    func cleanupDeletedGroups() async {
        do {
            // Get all groups from CloudKit
            let remoteGroups = try await cloudKitManager.fetchGroupsAsModels()
            
            // Find groups that should be deleted (Hawaii, Nuts, or any test groups)
            let groupsToDelete = remoteGroups.filter { group in
                let nameToCheck = group.name.lowercased()
                return nameToCheck == "hawaii" || nameToCheck == "nuts" || nameToCheck == "test"
            }
            
            if !groupsToDelete.isEmpty {
                print("⚠️ Found \(groupsToDelete.count) old groups to delete: \(groupsToDelete.map { $0.name }.joined(separator: ", "))")
                
                // Delete each group
                for group in groupsToDelete {
                    do {
                        let record = group.toCKRecord()
                        try await cloudKitManager.deleteGroup(record)
                        print("✅ Deleted old group: \(group.name)")
                        
                        // Also remove from local array immediately
                        if let index = groups.firstIndex(where: { $0.id == group.id }) {
                            groups.remove(at: index)
                        }
                    } catch {
                        print("❌ Failed to delete group \(group.name): \(error)")
                    }
                }
                
                // Clean up local storage as well
                let offlineManager = OfflineStorageManager.shared
                var localGroups = offlineManager.loadGroups()
                localGroups.removeAll { group in
                    let nameToCheck = group.name.lowercased()
                    return nameToCheck == "hawaii" || nameToCheck == "nuts" || nameToCheck == "test"
                }
                offlineManager.saveGroups(localGroups)
                
                // Clean up associated expenses
                var localExpenses = offlineManager.loadExpenses()
                let deletedGroupIDs = Set(groupsToDelete.map { $0.id })
                localExpenses.removeAll { deletedGroupIDs.contains($0.groupReference) }
                offlineManager.saveExpenses(localExpenses)
                
                print("✅ Cleanup completed")
            } else {
                print("✅ No old groups found to clean up")
            }
        } catch {
            print("❌ Failed to cleanup old groups: \(error)")
        }
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
} 