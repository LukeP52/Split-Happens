//
//  ErrorHandler.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import Foundation
import SwiftUI

class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var showingError = false
    @Published var currentError: Error?
    @Published var canRetry = false
    
    private var retryAction: (() -> Void)?
    
    private init() {}
    
    func handle(_ error: Error, retry: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.currentError = error
            self.retryAction = retry
            self.canRetry = retry != nil
            self.showingError = true
            
            // Log error with context
            print("❌ Error handled: \(error.localizedDescription)")
            
            // Log additional context for debugging
            if let decodingError = error as? DecodingError {
                self.logDecodingError(decodingError)
            } else if let cloudKitError = error as NSError?, cloudKitError.domain.contains("CloudKit") {
                self.logCloudKitError(cloudKitError)
            }
        }
    }
    
    func clearError() {
        currentError = nil
        retryAction = nil
        canRetry = false
        showingError = false
    }
    
    func retry() {
        retryAction?()
        clearError()
    }
    
    // MARK: - Error Logging
    
    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            print("🔍 Data corruption: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            print("🔍 Missing key '\(key.stringValue)': \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            print("🔍 Type mismatch for \(type): \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            print("🔍 Value not found for \(type): \(context.debugDescription)")
        @unknown default:
            print("🔍 Unknown decoding error: \(error)")
        }
    }
    
    private func logCloudKitError(_ error: NSError) {
        print("🔍 CloudKit error code: \(error.code)")
        print("🔍 CloudKit error domain: \(error.domain)")
        print("🔍 CloudKit error details: \(error.userInfo)")
    }
}

// MARK: - View Extension

extension View {
    func withErrorHandling() -> some View {
        self.modifier(ErrorHandlingModifier())
    }
}

struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.showingError) {
                Button("OK") {
                    errorHandler.clearError()
                }
                
                if errorHandler.canRetry {
                    Button("Retry") {
                        errorHandler.retry()
                    }
                }
            } message: {
                Text(errorHandler.currentError?.localizedDescription ?? "An unexpected error occurred")
            }
    }
}

// MARK: - Error Types

enum SplitHappensError: LocalizedError {
    case invalidExpenseAmount
    case invalidGroupData
    case networkUnavailable
    case syncFailed
    case invalidParticipantData
    case calculationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidExpenseAmount:
            return "Please enter a valid expense amount"
        case .invalidGroupData:
            return "Group data is invalid or corrupted"
        case .networkUnavailable:
            return "Network connection is not available"
        case .syncFailed:
            return "Failed to sync data. Please try again"
        case .invalidParticipantData:
            return "Participant data is invalid"
        case .calculationError(let details):
            return "Calculation error: \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidExpenseAmount:
            return "Enter a number greater than 0"
        case .invalidGroupData:
            return "Try refreshing the group data"
        case .networkUnavailable:
            return "Check your internet connection"
        case .syncFailed:
            return "Check your internet connection and try again"
        case .invalidParticipantData:
            return "Add at least one participant to the group"
        case .calculationError:
            return "Try recalculating the balances"
        }
    }
}