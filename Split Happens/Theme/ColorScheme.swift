//
//  ColorScheme.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/19/25.
//

import SwiftUI

struct AppColors {
    // MARK: - Elegant Dark Theme
    
    // Primary Background Colors
    static let background = Color.black
    static let secondaryBackground = Color(red: 0.09, green: 0.09, blue: 0.11) // #18191C slightly lighter than pure black for depth
    static let tertiaryBackground = Color(red: 0.15, green: 0.15, blue: 0.17) // #26292B subtle elevation background
    
    // Text Colors
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.7, green: 0.7, blue: 0.7) // #b3b3b3
    static let tertiaryText = Color(red: 0.5, green: 0.5, blue: 0.5) // #808080
    
    // Accent Colors
    static let accent = Color(red: 0.46, green: 0.29, blue: 0.99) // Vibrant purple #7448FF
    static let accentSecondary = Color(red: 0.67, green: 0.54, blue: 1.0) // Soft lavender #AA8BFF
    
    // Status Colors
    static let success = Color(red: 0.2, green: 0.7, blue: 0.3) // #33b34d
    static let warning = Color(red: 0.9, green: 0.6, blue: 0.1) // #e6991a
    static let error = Color(red: 0.8, green: 0.2, blue: 0.2) // #cc3333
    
    // Interactive Colors
    static let cardBackground = Color(red: 0.06, green: 0.06, blue: 0.06) // #0f0f0f
    static let borderColor = Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    static let shadowColor = Color.black.opacity(0.3)
    
    // Category Colors (Elegant versions)
    static let categoryFood = Color(red: 0.9, green: 0.5, blue: 0.3) // Warm orange
    static let categoryTransport = Color(red: 0.3, green: 0.6, blue: 0.9) // Cool blue
    static let categoryEntertainment = Color(red: 0.7, green: 0.4, blue: 0.8) // Purple
    static let categoryUtilities = Color(red: 0.9, green: 0.7, blue: 0.2) // Gold
    static let categoryRent = Color(red: 0.4, green: 0.7, blue: 0.3) // Green
    static let categoryShopping = Color(red: 0.9, green: 0.4, blue: 0.6) // Pink
    static let categoryTravel = Color(red: 0.3, green: 0.8, blue: 0.8) // Cyan
    static let categoryOther = Color(red: 0.6, green: 0.6, blue: 0.6) // Gray
}

// MARK: - SwiftUI Extensions for Theme

extension Color {
    static let appBackground = AppColors.background
    static let appSecondaryBackground = AppColors.secondaryBackground
    static let appTertiaryBackground = AppColors.tertiaryBackground
    static let appPrimaryText = AppColors.primaryText
    static let appSecondaryText = AppColors.secondaryText
    static let appTertiaryText = AppColors.tertiaryText
    static let appAccent = AppColors.accent
    static let appAccentSecondary = AppColors.accentSecondary
    static let appCardBackground = AppColors.cardBackground
    static let appBorderColor = AppColors.borderColor
}

// MARK: - Theme Modifiers

struct ElegantCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 0.8)
            )
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 4)
            .cornerRadius(12)
    }
}

struct ElegantTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.tertiaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.borderColor, lineWidth: 1)
            )
            .cornerRadius(8)
            .foregroundColor(AppColors.primaryText)
    }
}

extension View {
    func elegantCard() -> some View {
        modifier(ElegantCardStyle())
    }
    
    func elegantTextField() -> some View {
        modifier(ElegantTextFieldStyle())
    }
}