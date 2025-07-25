// ColorScheme.swift - Updated for modern fintech design
import SwiftUI

struct AppColors {
    // MARK: - Modern Fintech Dark Theme
    
    // Primary Background Colors
    static let background = Color(red: 0.05, green: 0.05, blue: 0.07) // Deep dark background
    static let secondaryBackground = Color(red: 0.08, green: 0.08, blue: 0.10) // Card backgrounds
    static let tertiaryBackground = Color(red: 0.12, green: 0.12, blue: 0.14) // Elevated surfaces
    
    // Glass effect backgrounds
    static let glassBackground = Color.white.opacity(0.05)
    static let glassStroke = Color.white.opacity(0.1)
    
    // Text Colors
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.75, green: 0.75, blue: 0.77) // Muted text
    static let tertiaryText = Color(red: 0.5, green: 0.5, blue: 0.52) // Very muted text
    
    // Vibrant Accent Colors (matching the purple in the image)
    static let accent = Color(red: 0.45, green: 0.28, blue: 0.98) // Vibrant purple #7347FA
    static let accentSecondary = Color(red: 0.55, green: 0.40, blue: 1.0) // Lighter purple
    static let accentGradientStart = Color(red: 0.55, green: 0.35, blue: 1.0)
    static let accentGradientEnd = Color(red: 0.35, green: 0.20, blue: 0.85)
    
    // Status Colors
    static let success = Color(red: 0.24, green: 0.84, blue: 0.37) // Bright green
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.0) // Orange
    static let error = Color(red: 1.0, green: 0.27, blue: 0.27) // Red
    
    // Card and UI Element Colors
    static let cardBackground = Color(red: 0.09, green: 0.09, blue: 0.11) // Slightly elevated
    static let cardBackgroundElevated = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let borderColor = Color.white.opacity(0.08)
    static let shadowColor = Color.black.opacity(0.5)
    
    // Interactive Elements
    static let buttonBackground = accent
    static let buttonBackgroundSecondary = Color(red: 0.15, green: 0.15, blue: 0.17)
    static let tabBarBackground = Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.95)
    
    // Chart Colors
    static let chartPrimary = accent
    static let chartSecondary = Color(red: 0.3, green: 0.8, blue: 0.6)
    static let chartTertiary = Color(red: 0.9, green: 0.5, blue: 0.3)
    
    // Category Colors
    static let categoryFood = Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
    static let categoryTransport = Color(red: 0.0, green: 0.7, blue: 1.0) // Blue
    static let categoryEntertainment = Color(red: 1.0, green: 0.2, blue: 0.6) // Pink
    static let categoryUtilities = Color(red: 0.5, green: 0.8, blue: 0.3) // Green
    static let categoryRent = Color(red: 0.8, green: 0.4, blue: 1.0) // Purple
    static let categoryShopping = Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow
    static let categoryTravel = Color(red: 0.2, green: 0.8, blue: 0.8) // Teal
    static let categoryOther = Color(red: 0.6, green: 0.6, blue: 0.6) // Gray
}

// MARK: - Updated Theme Modifiers

struct ModernCardStyle: ViewModifier {
    var isElevated: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isElevated ? AppColors.cardBackgroundElevated : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.borderColor, lineWidth: 0.5)
            )
            .shadow(color: AppColors.shadowColor, radius: 15, x: 0, y: 8)
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.glassStroke, lineWidth: 1)
            )
    }
}

struct AccentGradientStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [AppColors.accentGradientStart, AppColors.accentGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

extension View {
    func modernCard(isElevated: Bool = false) -> some View {
        modifier(ModernCardStyle(isElevated: isElevated))
    }
    
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
    
    func accentGradient() -> some View {
        modifier(AccentGradientStyle())
    }
}