//
//  AlertManager.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI
import Combine

enum AlertType: Identifiable {
    case cloudKitError(String)
    case groupError(String)
    case expenseError(String)
    case subscriptionError(String)
    case validationError(String)
    
    var id: String {
        switch self {
        case .cloudKitError: return "cloudkit"
        case .groupError: return "group"
        case .expenseError: return "expense"
        case .subscriptionError: return "subscription"
        case .validationError: return "validation"
        }
    }
    
    var title: String {
        switch self {
        case .cloudKitError: return "CloudKit Error"
        case .groupError: return "Group Error"
        case .expenseError: return "Expense Error"
        case .subscriptionError: return "Subscription Error"
        case .validationError: return "Validation Error"
        }
    }
    
    var message: String {
        switch self {
        case .cloudKitError(let msg): return msg
        case .groupError(let msg): return msg
        case .expenseError(let msg): return msg
        case .subscriptionError(let msg): return msg
        case .validationError(let msg): return msg
        }
    }
}

@MainActor
class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var currentAlert: AlertType?
    @Published var isShowingAlert = false
    
    private var alertQueue: [AlertType] = []
    private var isProcessingQueue = false
    
    private init() {}
    
    func showAlert(_ alert: AlertType) {
        // Ensure we're on main thread and not during view update
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showAlert(alert)
            }
            return
        }
        
        // Don't add alerts if we're already showing one
        guard !isShowingAlert else {
            alertQueue.append(alert)
            return
        }
        
        // Add to queue
        alertQueue.append(alert)
        processQueue()
    }
    
    func dismissAlert() {
        currentAlert = nil
        isShowingAlert = false
        
        // Small delay before processing next alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.processQueue()
        }
    }
    
    private func processQueue() {
        guard !isProcessingQueue && !alertQueue.isEmpty && !isShowingAlert else {
            return
        }
        
        isProcessingQueue = true
        let nextAlert = alertQueue.removeFirst()
        
        // Small delay to ensure any existing presentation is fully dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentAlert = nextAlert
            self.isShowingAlert = true
            self.isProcessingQueue = false
        }
    }
    
    // Convenience methods for different error types
    func showCloudKitError(_ message: String) {
        showAlert(.cloudKitError(message))
    }
    
    func showGroupError(_ message: String) {
        showAlert(.groupError(message))
    }
    
    func showExpenseError(_ message: String) {
        showAlert(.expenseError(message))
    }
    
    func showSubscriptionError(_ message: String) {
        showAlert(.subscriptionError(message))
    }
    
    func showValidationError(_ message: String) {
        showAlert(.validationError(message))
    }
}

// MARK: - SwiftUI View Extension

extension View {
    func withCentralizedAlerts() -> some View {
        modifier(CentralizedAlertModifier())
    }
}

struct CentralizedAlertModifier: ViewModifier {
    @StateObject private var alertManager = AlertManager.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                alertManager.currentAlert?.title ?? "Alert",
                isPresented: $alertManager.isShowingAlert,
                presenting: alertManager.currentAlert
            ) { alert in
                Button("OK") {
                    alertManager.dismissAlert()
                }
            } message: { alert in
                Text(alert.message)
            }
    }
}