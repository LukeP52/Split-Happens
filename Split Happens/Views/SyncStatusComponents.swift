//
//  SyncStatusComponents.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI

// MARK: - Sync Status Badge

struct SyncStatusBadge: View {
    let status: SyncStatus
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: size.iconSize))
                .foregroundColor(status.color)
            
            if size != .small {
                Text(status.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding / 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Global Sync Status Bar

struct GlobalSyncStatusBar: View {
    @StateObject private var offlineManager = OfflineStorageManager.shared
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            if offlineManager.syncStatus != .synced {
                Button {
                    showingDetails = true
                } label: {
                    HStack {
                        Image(systemName: offlineManager.syncStatus.icon)
                            .foregroundColor(offlineManager.syncStatus.color)
                        
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if offlineManager.pendingOperationsCount > 0 {
                            Text("\(offlineManager.pendingOperationsCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Circle().fill(Color.blue))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(offlineManager.syncStatus.color.opacity(0.1))
                }
                .buttonStyle(.plain)
                
                Divider()
            }
        }
        .sheet(isPresented: $showingDetails) {
            SyncDetailsView()
        }
    }
    
    private var statusMessage: String {
        switch offlineManager.syncStatus {
        case .synced:
            return "All data synced"
        case .syncing:
            return "Syncing \(offlineManager.pendingOperationsCount) items..."
        case .offline:
            return "Offline - \(offlineManager.pendingOperationsCount) items pending"
        case .conflict:
            return "Sync conflicts detected"
        case .failed:
            return "Sync failed - tap to retry"
        }
    }
}

// MARK: - Sync Details View

struct SyncDetailsView: View {
    @StateObject private var offlineManager = OfflineStorageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: offlineManager.syncStatus.icon)
                            .foregroundColor(offlineManager.syncStatus.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(offlineManager.syncStatus.description)
                                .font(.headline)
                            
                            if let lastSync = offlineManager.lastSyncTime {
                                Text("Last synced: \(lastSync, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never synced")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if offlineManager.isOnline {
                            Image(systemName: "wifi")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Sync Status")
                }
                
                if offlineManager.pendingOperationsCount > 0 {
                    Section {
                        Label("\(offlineManager.pendingOperationsCount) operations pending", 
                              systemImage: "clock")
                            .foregroundColor(.orange)
                        
                        if offlineManager.isOnline {
                            Button("Sync Now") {
                                Task {
                                    await offlineManager.forceSyncNow()
                                }
                            }
                        }
                    } header: {
                        Text("Pending Operations")
                    }
                }
                
                Section {
                    Button("Clear Local Data") {
                        offlineManager.clearLocalData()
                        dismiss()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("This will remove all locally stored data and force a fresh sync from the server.")
                        .font(.caption)
                }
            }
            .navigationTitle("Sync Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Item Sync Status Row

struct ItemSyncStatusRow: View {
    let itemId: String
    @StateObject private var offlineManager = OfflineStorageManager.shared
    
    private var syncStatus: SyncStatus {
        offlineManager.getSyncStatus(for: itemId)
    }
    
    var body: some View {
        HStack {
            SyncStatusBadge(status: syncStatus, size: .small)
            
            if let item = offlineManager.getSyncableItem(for: itemId) {
                VStack(alignment: .leading, spacing: 2) {
                    if item.isLocalOnly {
                        Text("Local only")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Modified: \(item.lastModified, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Animated Sync Indicator

struct AnimatedSyncIndicator: View {
    let status: SyncStatus
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: status.icon)
            .foregroundColor(status.color)
            .rotationEffect(.degrees(isAnimating && status == .syncing ? 360 : 0))
            .animation(
                status == .syncing ? 
                Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : 
                .default,
                value: isAnimating
            )
            .onAppear {
                if status == .syncing {
                    isAnimating = true
                }
            }
            .onChange(of: status) { newStatus in
                isAnimating = newStatus == .syncing
            }
    }
}

// MARK: - Sync Status Pills

struct SyncStatusPill: View {
    let status: SyncStatus
    let showText: Bool
    
    init(status: SyncStatus, showText: Bool = true) {
        self.status = status
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: 4) {
            AnimatedSyncIndicator(status: status)
                .font(.caption)
            
            if showText {
                Text(status.description)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(status.color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Conflict Resolution Alert

struct ConflictResolutionAlert: View {
    let conflictedItems: [SyncableItem]
    let onResolve: (SyncableItem, Bool) -> Void // Bool: true for keep local, false for use remote
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Some items have conflicts between local and remote versions. Choose which version to keep for each item.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Sync Conflicts")
                }
                
                ForEach(conflictedItems) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Item: \(item.id)")
                            .font(.headline)
                        
                        Text("Modified: \(item.lastModified, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Button("Keep Local") {
                                onResolve(item, true)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Use Remote") {
                                onResolve(item, false)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Resolve Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SyncStatusBadge(status: .synced, size: .small)
        SyncStatusBadge(status: .syncing, size: .medium)
        SyncStatusBadge(status: .offline, size: .large)
        SyncStatusPill(status: .conflict)
        GlobalSyncStatusBar()
    }
    .padding()
}