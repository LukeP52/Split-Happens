// GradientBackground.swift - Updated for modern look
import SwiftUI

struct ModernGradientBackground: View {
    var body: some View {
        ZStack {
            // Base dark background
            AppColors.background
                .ignoresSafeArea()
            
            // Static gradient orbs (no animation)
            GeometryReader { geometry in
                ZStack {
                    // Purple orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.accent.opacity(0.5),
                                    AppColors.accent.opacity(0.2),
                                    AppColors.accent.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .position(
                            x: geometry.size.width * 0.85,
                            y: geometry.size.height * 0.2
                        )
                        .blur(radius: 60)
                    
                    // Secondary purple orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.accentSecondary.opacity(0.4),
                                    AppColors.accentSecondary.opacity(0.1),
                                    AppColors.accentSecondary.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .position(
                            x: geometry.size.width * 0.15,
                            y: geometry.size.height * 0.7
                        )
                        .blur(radius: 50)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// Keep the old GradientBackground for compatibility
struct GradientBackground: View {
    var body: some View {
        ModernGradientBackground()
    }
}