//
//  Expense.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import CloudKit

enum SplitType: String, CaseIterable, Codable {
    case equal = "Equal"
    case percentage = "Percentage"
    case custom = "Custom"
    
    var displayName: String {
        rawValue
    }
    
    var description: String {
        switch self {
        case .equal:
            return "Split equally among all participants"
        case .percentage:
            return "Split by percentage for each participant"
        case .custom:
            return "Custom amount for each participant"
        }
    }
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food"
    case transportation = "Transportation"
    case entertainment = "Entertainment"
    case utilities = "Utilities"
    case rent = "Rent"
    case shopping = "Shopping"
    case travel = "Travel"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transportation: return "car"
        case .entertainment: return "tv"
        case .utilities: return "bolt"
        case .rent: return "house"
        case .shopping: return "bag"
        case .travel: return "airplane"
        case .other: return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .food: return "orange"
        case .transportation: return "blue"
        case .entertainment: return "purple"
        case .utilities: return "yellow"
        case .rent: return "green"
        case .shopping: return "pink"
        case .travel: return "cyan"
        case .other: return "gray"
        }
    }
}

struct ParticipantSplit: Codable {
    let participantName: String
    let participantID: String
    var amount: Double
    var percentage: Double
    
    init(participantName: String, participantID: String, amount: Double = 0.0, percentage: Double = 0.0) {
        self.participantName = participantName
        self.participantID = participantID
        self.amount = amount
        self.percentage = percentage
    }
}

struct Expense: Identifiable, Codable {
    let id: String
    var groupReference: String
    var description: String
    var totalAmount: Double
    var paidBy: String
    var paidByID: String
    var splitType: SplitType
    var date: Date
    var category: ExpenseCategory
    var participantNames: [String]
    var customSplits: [ParticipantSplit]
    
    init(id: String = UUID().uuidString,
         groupReference: String,
         description: String,
         totalAmount: Double,
         paidBy: String,
         paidByID: String,
         splitType: SplitType = .equal,
         date: Date = Date(),
         category: ExpenseCategory = .other,
         participantNames: [String] = [],
         customSplits: [ParticipantSplit] = []) {
        self.id = id
        self.groupReference = groupReference
        self.description = description
        self.totalAmount = totalAmount
        self.paidBy = paidBy
        self.paidByID = paidByID
        self.splitType = splitType
        self.date = date
        self.category = category
        self.participantNames = participantNames
        self.customSplits = customSplits
    }
    
    // MARK: - CloudKit Integration
    
    init?(from record: CKRecord) {
        // Get the group reference as a string (the record name)
        let groupReference: String
        if let ref = record["groupReference"] as? CKRecord.Reference {
            groupReference = ref.recordID.recordName
        } else if let str = record["groupReference"] as? String {
            groupReference = str
        } else {
            print("❌ Expense init failed - invalid groupReference type")
            return nil
        }
        
        guard let description = record["description"] as? String,
              let paidBy = record["paidBy"] as? String,
              let paidByID = record["paidByID"] as? String,
              let splitTypeRaw = record["splitType"] as? String,
              let splitType = SplitType(rawValue: splitTypeRaw),
              let categoryRaw = record["category"] as? String,
              let category = ExpenseCategory(rawValue: categoryRaw) else {
            print("❌ Expense init failed - missing required fields")
            return nil
        }
        
        self.id = record.recordID.recordName
        self.groupReference = groupReference
        self.description = description
        self.totalAmount = record["totalAmount"] as? Double ?? 0
        self.paidBy = paidBy
        self.paidByID = paidByID
        self.splitType = splitType
        self.date = record["date"] as? Date ?? Date()
        self.category = category
        self.participantNames = record["participantNames"] as? [String] ?? []
        self.customSplits = []
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Expense", recordID: recordID)
        
        // Create a proper reference for the group
        let groupRecordID = CKRecord.ID(recordName: groupReference)
        let groupRef = CKRecord.Reference(recordID: groupRecordID, action: .deleteSelf)
        record["groupReference"] = groupRef
        
        record["description"] = description
        record["totalAmount"] = totalAmount
        record["paidBy"] = paidBy
        record["paidByID"] = paidByID
        record["splitType"] = splitType.rawValue
        record["date"] = date
        record["category"] = category.rawValue
        record["participantNames"] = participantNames
        
        return record
    }
    
    // MARK: - Split Calculation Logic
    
    func calculateSplitAmounts() -> [String: Double] {
        var splits: [String: Double] = [:]
        
        switch splitType {
        case .equal:
            guard participantNames.count > 0 else { break }
            let amountPerPerson = NaNDetector.shared.validate(totalAmount / Double(participantNames.count), context: "Expense.calculateSplitAmounts.equal")
            for participant in participantNames {
                splits[participant] = amountPerPerson
            }
            
        case .percentage:
            for split in customSplits {
                let amount = NaNDetector.shared.validate(totalAmount * (split.percentage / 100.0), context: "Expense.calculateSplitAmounts.percentage")
                splits[split.participantName] = amount
            }
            
        case .custom:
            for split in customSplits {
                splits[split.participantName] = split.amount
            }
        }
        
        return splits
    }
    
    func amountOwedBy(_ participantName: String) -> Double {
        let splits = calculateSplitAmounts()
        return splits[participantName] ?? 0.0
    }
    
    func amountPaidByParticipant(_ participantName: String) -> Double {
        return participantName == paidBy ? totalAmount : 0.0
    }
    
    func netAmountFor(_ participantName: String) -> Double {
        let owed = amountOwedBy(participantName)
        let paid = amountPaidByParticipant(participantName)
        return paid - owed
    }
    
    mutating func updateSplitForParticipant(_ participantName: String, amount: Double? = nil, percentage: Double? = nil) {
        guard let participantID = customSplits.first(where: { $0.participantName == participantName })?.participantID ??
                participantNames.first(where: { $0 == participantName }).map({ _ in UUID().uuidString }) else { return }
        
        if let index = customSplits.firstIndex(where: { $0.participantName == participantName }) {
            if let amount = amount {
                customSplits[index].amount = amount
            }
            if let percentage = percentage {
                customSplits[index].percentage = percentage
            }
        } else {
            let split = ParticipantSplit(
                participantName: participantName,
                participantID: participantID,
                amount: amount ?? 0.0,
                percentage: percentage ?? 0.0
            )
            customSplits.append(split)
        }
    }
    
    mutating func generateEqualSplits() {
        customSplits.removeAll()
        guard participantNames.count > 0 else { return }
        let amountPerPerson = NaNDetector.shared.validate(totalAmount / Double(participantNames.count), context: "Expense.generateEqualSplits.amountPerPerson")
        let percentagePerPerson = NaNDetector.shared.validate(100.0 / Double(participantNames.count), context: "Expense.generateEqualSplits.percentagePerPerson")
        
        for participant in participantNames {
            let split = ParticipantSplit(
                participantName: participant,
                participantID: UUID().uuidString,
                amount: amountPerPerson,
                percentage: percentagePerPerson
            )
            customSplits.append(split)
        }
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        switch splitType {
        case .equal:
            return !participantNames.isEmpty && totalAmount > 0
        case .percentage:
            let totalPercentage = customSplits.reduce(0) { $0 + $1.percentage }
            return abs(totalPercentage - 100.0) < 0.01 && totalAmount > 0
        case .custom:
            let totalSplitAmount = customSplits.reduce(0) { total, split in
                guard split.amount.isFinite else { return total }
                return total + split.amount
            }
            return abs(totalSplitAmount - totalAmount) < 0.01 && totalAmount > 0
        }
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Description cannot be empty")
        }
        
        if totalAmount <= 0 {
            errors.append("Amount must be greater than 0")
        }
        
        if participantNames.isEmpty {
            errors.append("Must have at least one participant")
        }
        
        switch splitType {
        case .equal:
            break
        case .percentage:
            let totalPercentage = customSplits.reduce(0) { $0 + $1.percentage }
            if abs(totalPercentage - 100.0) >= 0.01 {
                errors.append("Percentages must add up to 100%")
            }
        case .custom:
            let totalSplitAmount = customSplits.reduce(0) { total, split in
                guard split.amount.isFinite else { return total }
                return total + split.amount
            }
            if abs(totalSplitAmount - totalAmount) >= 0.01 {
                errors.append("Custom split amounts must add up to total amount")
            }
        }
        
        return errors
    }
    
    // MARK: - Computed Properties
    
    var formattedAmount: String {
        let safeAmount = totalAmount.isFinite ? totalAmount : 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: safeAmount)) ?? "$0.00"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }
    
    var isRecent: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date()) ||
        date.timeIntervalSinceNow > -86400
    }
    
    var participantCount: Int {
        participantNames.count
    }
    
    var equalSplitAmount: Double {
        guard participantCount > 0 else { return 0.0 }
        return NaNDetector.shared.validate(totalAmount / Double(participantCount), context: "Expense.equalSplitAmount")
    }
    
    var formattedEqualSplitAmount: String {
        let safeAmount = equalSplitAmount.isFinite ? equalSplitAmount : 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: safeAmount)) ?? "$0.00"
    }
    
    // MARK: - Helper Methods
    
    func contains(participant: String) -> Bool {
        participantNames.contains(participant)
    }
    
    mutating func addParticipant(_ participant: String) {
        guard !participantNames.contains(participant) else { return }
        participantNames.append(participant)
        
        if splitType != .equal {
            generateEqualSplits()
        }
    }
    
    mutating func removeParticipant(_ participant: String) {
        participantNames.removeAll { $0 == participant }
        customSplits.removeAll { $0.participantName == participant }
        
        if splitType != .equal && !participantNames.isEmpty {
            generateEqualSplits()
        }
    }
} 