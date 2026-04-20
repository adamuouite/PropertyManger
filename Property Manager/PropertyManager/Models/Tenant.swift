import SwiftData
import Foundation

@Model
final class Tenant {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var idNumber: String = ""
    /// Unique tenant reference number used in rent transactions (e.g. "M-001")
    var tenantNumber: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    /// Filename of attached ID document (image or PDF) stored in ~/Documents/PropertyManager/TenantDocs/
    var idDocumentFilename: String? = nil
    var isArchived: Bool = false
    var archivedAt: Date? = nil

    @Relationship(deleteRule: .nullify) var contracts: [Contract] = []

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    init(
        firstName: String,
        lastName: String,
        email: String,
        phone: String,
        idNumber: String = "",
        tenantNumber: String = "",
        notes: String = ""
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.idNumber = idNumber
        self.tenantNumber = tenantNumber
        self.notes = notes
        self.createdAt = Date()
    }
}
