//
//  ContentView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var alertManager = AlertManager.shared
    
    var body: some View {
        ZStack {
            // Decorative gradient blobs
            GradientBackground()
            
            SwiftUI.Group {
                if cloudKitManager.isSignedInToiCloud {
                    GroupListView()
                } else {
                    iCloudSignInView()
                }
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .withCentralizedAlerts()
        .onReceive(cloudKitManager.$error) { error in
            guard let errorMessage = error else { return }
            Task { @MainActor in
                alertManager.showCloudKitError(errorMessage)
            }
        }
    }
}

struct iCloudSignInView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "icloud")
                .font(.system(size: 80))
                .foregroundColor(AppColors.accentSecondary)
            
            Text("Sign in to iCloud")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            
            Text("Split Happens requires iCloud to sync your expense groups across devices.")
                .font(.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text("To use this app:")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(AppColors.accent)
                        Text("Sign in to iCloud in Settings")
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    HStack {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(AppColors.accent)
                        Text("Enable CloudKit for this app")
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    HStack {
                        Image(systemName: "3.circle.fill")
                            .foregroundColor(AppColors.accent)
                        Text("Return to the app")
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .font(.body)
            }
            .padding()
            .background(AppColors.secondaryBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
        .background(AppColors.background.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
