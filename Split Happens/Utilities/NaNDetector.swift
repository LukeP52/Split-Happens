//
//  NaNDetector.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation

class NaNDetector {
    static let shared = NaNDetector()
    
    private init() {}
    
    /// Validates a Double value and logs if it's NaN or infinite
    func validate(_ value: Double, context: String) -> Double {
        if value.isNaN {
            print("🚨 NaN detected in \(context): \(value)")
            assertionFailure("NaN detected in \(context)")
            return 0.0
        }
        
        if value.isInfinite {
            print("🚨 Infinite value detected in \(context): \(value)")
            assertionFailure("Infinite value detected in \(context)")
            return 0.0
        }
        
        return value
    }
    
    /// Validates an array of Double values
    func validate(_ values: [Double], context: String) -> [Double] {
        return values.map { validate($0, context: "\(context)[\(values.firstIndex(of: $0) ?? -1)]") }
    }
}

// Convenience extension for Double
extension Double {
    var nanSafe: Double {
        guard self.isFinite else {
            print("🚨 NaN/Infinite converted to 0: \(self)")
            return 0.0
        }
        return self
    }
    
    func validated(context: String) -> Double {
        return NaNDetector.shared.validate(self, context: context)
    }
}