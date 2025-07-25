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
            // Modern gradient background
            ModernGradientBackground()
            
            SwiftUI.Group {
                if cloudKitManager.isSignedInToiCloud {
                    MainTabView()
                } else {
                    ModerniCloudSignInView()
                }
            }
        }
        .preferredColorScheme(.dark)
        .withCentralizedAlerts()
        .onReceive(cloudKitManager.$error) { error in
            guard let errorMessage = error else { return }
            Task { @MainActor in
                alertManager.showCloudKitError(errorMessage)
            }
        }
    }
}

struct ModerniCloudSignInView: View {
    var body: some View {
        ZStack {
            ModernGradientBackground()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icon
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.accent)
                    )
                
                // Content
                VStack(spacing: 16) {
                    Text("Sign in to iCloud")
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("Split Happens requires iCloud to sync your expense groups across devices.")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Instructions card
                VStack(spacing: 20) {
                    Text("To use this app:")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionRow(number: "1", text: "Open Settings app")
                        InstructionRow(number: "2", text: "Sign in to your Apple ID")
                        InstructionRow(number: "3", text: "Enable iCloud Drive")
                        InstructionRow(number: "4", text: "Return to Split Happens")
                    }
                }
                .padding(24)
                .background(AppColors.cardBackground)
                .modernCard()
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Settings button
                Button(action: openSettings) {
                    HStack {
                        Image(systemName: "gear")
                            .font(.body)
                        Text("Open Settings")
                            .font(AppFonts.bodyMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accentGradientStart, AppColors.accentGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                
                Spacer()
            }
            .padding(20)
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(number)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(.white)
                )
            
            Text(text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
