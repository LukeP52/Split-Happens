import Foundation
import SwiftUI
import Combine

struct ActivityItem: Identifiable {
    let id = UUID()
    let groupName: String
    let description: String
    let date: Date
    let amount: Double
    let paidBy: String
    let currency: String
}

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var items: [ActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let groupVM: GroupViewModel = GroupViewModel.shared ?? GroupViewModel()
    private let cloudKit = CloudKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        observeChanges()
        Task { await reload() }
    }
    
    private func observeChanges() {
        NotificationCenter.default.publisher(for: .expensesDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .groupsDidChange))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.reload() }
            }
            .store(in: &cancellables)
    }
    
    func reload() async {
        isLoading = true
        errorMessage = nil
        var temp: [ActivityItem] = []
        do {
            for group in groupVM.groups {
                let expenses = try await cloudKit.fetchExpensesAsModels(for: group.id)
                for e in expenses {
                    temp.append(ActivityItem(
                        groupName: group.name,
                        description: e.description,
                        date: e.date,
                        amount: e.totalAmount,
                        paidBy: e.paidBy,
                        currency: group.currency
                    ))
                }
            }
            items = temp.sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
} 