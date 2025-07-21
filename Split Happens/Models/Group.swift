//
//  Group.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import CloudKit

struct Group: Identifiable, Codable {
    let id: String
    var name: String
    var participants: [String]
    var participantIDs: [String]
    var totalSpent: Double
    var lastActivity: Date
    var isActive: Bool
    var currency: String
    
    init(id: String = UUID().uuidString,
         name: String,
         participants: [String] = [],
         participantIDs: [String] = [],
         totalSpent: Double = 0.0,
         lastActivity: Date = Date(),
         isActive: Bool = true,
         currency: String = "USD") {
        self.id = id
        self.name = name
        self.participants = participants
        
        // Ensure participantIDs match participants count
        if participantIDs.count == participants.count {
            self.participantIDs = participantIDs
        } else {
            self.participantIDs = participants.map { _ in UUID().uuidString }
        }
        
        // Ensure totalSpent is finite
        self.totalSpent = totalSpent.isFinite ? totalSpent : 0.0
        
        self.lastActivity = lastActivity
        self.isActive = isActive
        self.currency = currency
    }
    
    // MARK: - CloudKit Integration
    
    init?(from record: CKRecord) {
        let name = record.groupName
        guard !name.isEmpty else { return nil }
        
        self.id = record.recordID.recordName
        self.name = name
        self.participants = record.participants
        self.participantIDs = record.participantIDs
        self.totalSpent = record.totalSpent
        self.lastActivity = record.lastActivity
        self.isActive = record.isActive
        self.currency = record.currency
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Group", recordID: recordID)
        record["name"] = name
        record["participants"] = participants
        record["participantIDs"] = participantIDs
        record["totalSpent"] = totalSpent
        record["lastActivity"] = lastActivity
        record["isActive"] = isActive
        record["currency"] = currency
        return record
    }
    
    // MARK: - Computed Properties
    
    var participantCount: Int {
        participants.count
    }
    
    var formattedTotalSpent: String {
        let safeAmount = totalSpent.isFinite ? totalSpent : 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: safeAmount)) ?? "\(currency) 0.00"
    }
    
    var averageSpentPerPerson: Double {
        guard participantCount > 0 && totalSpent.isFinite else { return 0.0 }
        let avg = totalSpent / Double(participantCount)
        return avg.isFinite ? avg : 0.0
    }
    
    var formattedAverageSpent: String {
        let amount = averageSpentPerPerson
        guard amount.isFinite && amount > 0 else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var isRecentlyActive: Bool {
        Calendar.current.isDate(lastActivity, inSameDayAs: Date()) ||
        lastActivity.timeIntervalSinceNow > -86400 // Within 24 hours
    }
    
    // MARK: - Helper Methods
    
    mutating func addParticipant(_ participant: String, id: String? = nil) {
        let participantName = participant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !participantName.isEmpty, !participants.contains(participantName) else { return }
        
        participants.append(participantName)
        participantIDs.append(id ?? UUID().uuidString)
        lastActivity = Date()
    }
    
    mutating func removeParticipant(_ participant: String) {
        guard let index = participants.firstIndex(of: participant) else { return }
        
        participants.remove(at: index)
        if index < participantIDs.count {
            participantIDs.remove(at: index)
        }
        lastActivity = Date()
    }
    
    mutating func updateParticipant(at index: Int, newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < participants.count, !trimmedName.isEmpty else { return }
        
        participants[index] = trimmedName
        lastActivity = Date()
    }
    
    mutating func updateTotalSpent(_ amount: Double) {
        totalSpent += amount
        lastActivity = Date()
    }
    
    mutating func recalculateTotalSpent(from expenses: [Expense]) {
        totalSpent = expenses.reduce(0) { total, expense in
            guard expense.totalAmount.isFinite else { return total }
            return total + expense.totalAmount
        }
        lastActivity = Date()
    }
    
    mutating func deactivate() {
        isActive = false
        lastActivity = Date()
    }
    
    mutating func activate() {
        isActive = true
        lastActivity = Date()
    }
    
    func contains(participant: String) -> Bool {
        participants.contains(participant)
    }
    
    func participantID(for participant: String) -> String? {
        guard let index = participants.firstIndex(of: participant),
              index < participantIDs.count else { return nil }
        return participantIDs[index]
    }
    
    func participantName(for id: String) -> String? {
        guard let index = participantIDs.firstIndex(of: id),
              index < participants.count else { return nil }
        return participants[index]
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        participantCount >= 2 &&
        participants.count == participantIDs.count
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Group name cannot be empty")
        }
        
        if participantCount < 2 {
            errors.append("Group must have at least 2 participants")
        }
        
        if participants.count != participantIDs.count {
            errors.append("Participant data is inconsistent")
        }
        
        let duplicateParticipants = Dictionary(grouping: participants, by: { $0 })
            .filter { $1.count > 1 }
            .keys
        
        if !duplicateParticipants.isEmpty {
            errors.append("Duplicate participants found: \(duplicateParticipants.joined(separator: ", "))")
        }
        
        return errors
    }
} 