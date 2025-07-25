//
//  ExpenseCategory+Extensions.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import SwiftUI

extension ExpenseCategory {
    // Convert the string color to SwiftUI Color
    var swiftUIColor: Color {
        switch self {
        case .food:
            return .orange
        case .transportation:
            return .blue
        case .entertainment:
            return .purple
        case .utilities:
            return .yellow
        case .rent:
            return .green
        case .shopping:
            return .pink
        case .travel:
            return .cyan
        case .other:
            return AppColors.accent
        }
    }
    
    // Add display name property
    var displayName: String {
        switch self {
        case .food:
            return "Food"
        case .transportation:
            return "Transport"
        case .entertainment:
            return "Fun"
        case .utilities:
            return "Utilities"
        case .rent:
            return "Housing"
        case .shopping:
            return "Shopping"
        case .travel:
            return "Travel"
        case .other:
            return "Other"
        }
    }
}