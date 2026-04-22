import Foundation
import SwiftUI

enum UserAction {
    case manageUsers
    case manageApartments
    case manageContracts
    case manageTenants
    case managePayments
}

class AuthManager: ObservableObject {
    @Published var currentUser: AppUser?

    var isLoggedIn: Bool { currentUser != nil }

    func login(_ user: AppUser) { currentUser = user }
    func logout() { currentUser = nil }

    func canPerform(_ action: UserAction) -> Bool {
        guard let user = currentUser else { return false }
        switch action {
        case .manageUsers:
            return user.role == .admin
        case .manageApartments, .manageContracts, .manageTenants:
            return user.role == .admin || user.role == .propertyManager
        case .managePayments:
            return user.role == .admin || user.role == .accountant
        }
    }
}
