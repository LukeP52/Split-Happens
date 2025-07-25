//
//  SettlementFlowView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import SwiftUI

struct SettlementFlowView: View {
    let friendBalance: FriendBalance
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Settlement header
                VStack(spacing: 16) {
                    PersonAvatar(name: friendBalance.friendName, size: 80)
                    
                    Text(friendBalance.formattedAmount)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(friendBalance.isOwed ? AppColors.success : AppColors.error)
                    
                    Text(friendBalance.oweDescription)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.vertical, 40)
                
                Spacer()
                
                // Settlement actions
                VStack(spacing: 16) {
                    Button("Record Payment") {
                        // TODO: Implement settlement recording
                        dismiss()
                    }
                    .buttonStyle(ModernAccentButton())
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(ModernSecondaryButton())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
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
    SettlementFlowView(
        friendBalance: FriendBalance(
            id: "1",
            friendName: "John Doe",
            amount: 50.0
        )
    )
}