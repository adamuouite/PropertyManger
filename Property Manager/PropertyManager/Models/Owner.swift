import SwiftData
import Foundation

@Model
final class Owner {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify) var contracts: [Contract] = []

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    var verwaltungsvertraege: [Contract] {
        contracts.filter { $0.category == .verwaltungsvertrag }
    }

    init(
        firstName: String,
        lastName: String,
        email: String,
        phone: String,
        notes: String = ""
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.notes = notes
        self.createdAt = Date()
    }
}

