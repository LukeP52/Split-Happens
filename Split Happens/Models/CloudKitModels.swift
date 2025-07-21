//
//  CloudKitModels.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import Foundation
import CloudKit

extension CKRecord {
    // MARK: - Group Convenience Properties
    
    var groupName: String {
        self["name"] as? String ?? ""
    }
    
    var participants: [String] {
        self["participants"] as? [String] ?? []
    }
    
    var participantIDs: [String] {
        self["participantIDs"] as? [String] ?? []
    }
    
    var totalSpent: Double {
        self["totalSpent"] as? Double ?? 0.0
    }
    
    var lastActivity: Date {
        self["lastActivity"] as? Date ?? Date()
    }
    
    var isActive: Bool {
        self["isActive"] as? Bool ?? true
    }
    
    var currency: String {
        self["currency"] as? String ?? "USD"
    }
    
    var formattedTotalSpent: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: totalSpent)) ?? "\(currency) 0.00"
    }
    
    var participantCount: Int {
        participants.count
    }
    
    // MARK: - Expense Convenience Properties
    
    var expenseGroupReference: String? {
        self["groupReference"] as? String
    }
    
    var expenseDescription: String? {
        self["description"] as? String
    }
    
    var expenseTotalAmount: Double {
        self["totalAmount"] as? Double ?? 0.0
    }
    
    var expensePaidBy: String? {
        self["paidBy"] as? String
    }
    
    var expensePaidByID: String? {
        self["paidByID"] as? String
    }
    
    var expenseSplitType: SplitType? {
        guard let rawValue = self["splitType"] as? String else { return nil }
        return SplitType(rawValue: rawValue)
    }
    
    var expenseDate: Date {
        self["date"] as? Date ?? Date()
    }
    
    var expenseCategory: ExpenseCategory? {
        guard let rawValue = self["category"] as? String else { return nil }
        return ExpenseCategory(rawValue: rawValue)
    }
    
    var expenseParticipantNames: [String] {
        self["participantNames"] as? [String] ?? []
    }
    
    var expenseCustomSplits: [ParticipantSplit] {
        guard let data = self["customSplits"] as? Data,
              let splits = try? JSONDecoder().decode([ParticipantSplit].self, from: data) else {
            return []
        }
        return splits
    }
    
    var formattedExpenseAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: expenseTotalAmount)) ?? "$0.00"
    }
    
    var formattedExpenseDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: expenseDate)
    }
    
    var shortExpenseDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: expenseDate)
    }
    
    var expenseCategoryIcon: String {
        expenseCategory?.icon ?? "questionmark.circle"
    }
    
    var expenseCategoryColor: String {
        expenseCategory?.color ?? "gray"
    }
    
    // MARK: - Helper Methods
    
    func containsParticipant(_ participant: String) -> Bool {
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
    
    var isRecentlyActive: Bool {
        Calendar.current.isDate(lastActivity, inSameDayAs: Date()) ||
        lastActivity.timeIntervalSinceNow > -86400
    }
    
    var isExpenseRecent: Bool {
        Calendar.current.isDate(expenseDate, inSameDayAs: Date()) ||
        expenseDate.timeIntervalSinceNow > -86400
    }
    
    // MARK: - Validation
    
    var isValidGroup: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        participantCount >= 2 &&
        participants.count == participantIDs.count
    }
    
    var isValidExpense: Bool {
        guard let description = expenseDescription,
              let _ = expensePaidBy,
              let _ = expensePaidByID,
              let splitType = expenseSplitType,
              let _ = expenseCategory else { return false }
        
        let descriptionValid = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let amountValid = expenseTotalAmount > 0
        let participantsValid = !expenseParticipantNames.isEmpty
        
        switch splitType {
        case .equal:
            return descriptionValid && amountValid && participantsValid
        case .percentage:
            let customSplits = expenseCustomSplits
            let totalPercentage = customSplits.reduce(0) { total, split in
                guard split.percentage.isFinite else { return total }
                return total + split.percentage
            }
            return descriptionValid && amountValid && participantsValid && abs(totalPercentage - 100.0) < 0.01
        case .custom:
            let customSplits = expenseCustomSplits
            let totalSplitAmount = customSplits.reduce(0) { total, split in
                guard split.amount.isFinite else { return total }
                return total + split.amount
            }
            return descriptionValid && amountValid && participantsValid && abs(totalSplitAmount - expenseTotalAmount) < 0.01
        }
    }
}

// MARK: - CloudKit Error Handling

enum CloudKitError: LocalizedError {
    case recordNotFound
    case invalidRecord
    case networkError
    case quotaExceeded
    case userDeletedZone
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .recordNotFound:
            return "Record not found"
        case .invalidRecord:
            return "Invalid record data"
        case .networkError:
            return "Network connection error"
        case .quotaExceeded:
            return "CloudKit quota exceeded"
        case .userDeletedZone:
            return "User deleted zone"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - CloudKit Result Types

struct CloudKitResult<T> {
    let success: Bool
    let data: T?
    let error: CloudKitError?
    
    static func success(_ data: T) -> CloudKitResult<T> {
        return CloudKitResult(success: true, data: data, error: nil)
    }
    
    static func failure(_ error: CloudKitError) -> CloudKitResult<T> {
        return CloudKitResult(success: false, data: nil, error: error)
    }
}

// MARK: - CloudKit Batch Operations

extension CKDatabase {
    func batchSave(_ records: [CKRecord]) async throws -> [CKRecord] {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []
            
            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    print("Failed to save record \(recordID): \(error)")
                }
            }
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success():
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.add(operation)
        }
    }
    
    func batchDelete(_ recordIDs: [CKRecord.ID]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.qualityOfService = .userInitiated
        
        try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.add(operation)
        }
    }
} 