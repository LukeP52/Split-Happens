//
//  SafeCircularProgress.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/22/25.
//

import SwiftUI

// Fix for the circular progress view in the header
struct SafeCircularProgress: View {
    let value: Double
    let total: Double
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        let result = (value / total)
        return min(max(result.safeValue, 0), 1) // Clamp between 0 and 1
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.tertiaryBackground, lineWidth: 8)
                .frame(width: 80, height: 80)
            
            Circle()
                .trim(from: 0, to: CGFloat(percentage))
                .stroke(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(percentage * 100))%")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
        }
    }
}