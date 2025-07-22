//
//  CloudKitManager+DeletionFix.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/22/25.
//

import Foundation
import CloudKit

// Add these methods to CloudKitManager

extension CloudKitManager {
    // Sync deletions from CloudKit to local
    func syncDeletedGroups() async throws {
        let localGroups = OfflineStorageManager.shared.loadGroups()
        let localGroupIDs = Set(localGroups.map { $0.id })
        
        // Fetch all groups from CloudKit using the existing public method
        let remoteGroups = try await fetchGroupsAsModels()
        let remoteGroupIDs = Set(remoteGroups.map { $0.id })
        
        // Find groups that exist locally but not in CloudKit
        let deletedGroupIDs = localGroupIDs.subtracting(remoteGroupIDs)
        
        if !deletedGroupIDs.isEmpty {
            print("🗑️ Found \(deletedGroupIDs.count) groups to delete locally")
            
            await MainActor.run {
                let offlineManager = OfflineStorageManager.shared
                var localGroups = offlineManager.loadGroups()
                var localExpenses = offlineManager.loadExpenses()
                
                // Remove deleted groups and their expenses
                for groupID in deletedGroupIDs {
                    localGroups.removeAll { $0.id == groupID }
                    localExpenses.removeAll { $0.groupReference == groupID }
                    // Update sync status instead of directly accessing private property
                    offlineManager.updateSyncStatus(for: groupID, status: .synced)
                }
                
                offlineManager.saveGroups(localGroups)
                offlineManager.saveExpenses(localExpenses)
            }
        }
    }
}