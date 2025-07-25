//
//  FriendBalance.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import Foundation

struct FriendBalance: Identifiable {
    let id: String
    let friendName: String
    let amount: Double // Positive = they owe you, Negative = you owe them
    
    var formattedAmount: String {
        formatCurrency(abs(amount))
    }
    
    var isOwed: Bool {
        amount > 0
    }
    
    var isPositive: Bool { 
        amount > 0.01 
    }
    
    var isNegative: Bool { 
        amount < -0.01 
    }
    
    var isSettled: Bool { 
        abs(amount) < 0.01 
    }
    
    var oweDescription: String {
        isOwed ? "\(friendName) owes you" : "You owe \(friendName)"
    }
}

struct GroupBalance: Identifiable {
    let id: String
    let groupName: String
    let friendName: String
    let amount: Double
    let lastActivity: Date
    
    var formattedAmount: String {
        formatCurrency(abs(amount))
    }
    
    var isOwed: Bool {
        amount > 0
    }
}