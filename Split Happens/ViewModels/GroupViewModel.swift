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
    @Published var groups: [Group] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotificationObservers()
        Task {
            await loadGroups()
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
            groups = fetchedGroups
        } catch {
            errorMessage = "Failed to load groups: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createGroup(name: String, participants: [String], currency: String = "USD") async {
        isLoading = true
        errorMessage = nil
        
        let newGroup = Group(
            name: name,
            participants: participants,
            participantIDs: participants.map { _ in UUID().uuidString },
            currency: currency
        )
        
        do {
            let savedGroup = try await cloudKitManager.saveGroup(newGroup)
            groups.append(savedGroup)
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
            groups.removeAll { $0.id == group.id }
        } catch {
            errorMessage = "Failed to delete group: \(error.localizedDescription)"
        }
        
        isLoading = false
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
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
} 