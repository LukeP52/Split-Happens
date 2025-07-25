import Foundation
import SwiftUI

struct CurrentUser {
    let name: String
    let email: String
    let avatarColor: Color
}

@MainActor
class AccountViewModel: ObservableObject {
    @Published var user: CurrentUser = CurrentUser(name: "Luke Peterson", email: "johnlukePeterson@gmail.com", avatarColor: .pink)
} 