//
//  Double+SafeValue.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/22/25.
//

import Foundation

// NaN Protection Fixes
// Add these extensions to protect against NaN values

extension Double {
    var safeValue: Double {
        guard self.isFinite else {
            print("⚠️ NaN/Infinite value detected, returning 0")
            return 0
        }
        return self
    }
}

// Updated formatCurrency to handle NaN
func formatCurrency(_ amount: Double, currency: String = "USD") -> String {
    let safeAmount = amount.safeValue
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: safeAmount)) ?? "$0.00"
}