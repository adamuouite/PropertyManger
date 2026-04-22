import SwiftData
import Foundation

enum UserRole: String, Codable, CaseIterable {
    case admin = "Admin"
    case propertyManager = "Property Manager"
    case accountant = "Accountant"

    var icon: String {
        switch self {
        case .admin: return "crown.fill"
        case .propertyManager: return "building.2.fill"
        case .accountant: return "chart.bar.fill"
        }
    }
}

@Model
final class AppUser {
    var username: String = ""
    var password: String = ""
    var fullName: String = ""
    var roleRaw: String = UserRole.propertyManager.rawValue
    var createdAt: Date = Date()

    var role: UserRole {
        get { UserRole(rawValue: roleRaw) ?? .propertyManager }
        set { roleRaw = newValue.rawValue }
    }

    init(username: String, password: String, fullName: String, role: UserRole) {
        self.username = username
        self.password = password
        self.fullName = fullName
        self.roleRaw = role.rawValue
        self.createdAt = Date()
    }
}
