// Typography.swift - Updated for modern fintech design
import SwiftUI

struct AppFonts {
    // Using SF Pro Rounded for a friendly fintech feel
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let footnote = Font.system(size: 12, weight: .regular, design: .default)
    
    // Special styles for numbers
    static let numberLarge = Font.system(size: 36, weight: .bold, design: .rounded)
    static let numberMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let numberSmall = Font.system(size: 18, weight: .medium, design: .rounded)
}