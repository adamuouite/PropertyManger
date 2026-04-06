import SwiftData
import Foundation

enum ContractType: String, Codable, CaseIterable {
    case tenant = "Tenant"
    case landlord = "Landlord"

    var icon: String {
        switch self {
        case .tenant: return "key.fill"
        case .landlord: return "person.badge.key.fill"
        }
    }
}

enum ContractStatus: String, Codable, CaseIterable {
    case active = "Active"
    case pending = "Pending"
    case expired = "Expired"
    case terminated = "Terminated"

    var icon: String {
        switch self {
        case .active: return "checkmark.seal.fill"
        case .pending: return "clock.fill"
        case .expired: return "calendar.badge.minus"
        case .terminated: return "xmark.circle.fill"
        }
    }
}

@Model
final class Contract {
    var contractNumber: String = ""
    var typeRaw: String = ContractType.tenant.rawValue
    var statusRaw: String = ContractStatus.active.rawValue
    var startDate: Date = Date()
    var endDate: Date = Date()
    var rentAmount: Double = 0
    var depositAmount: Double = 0
    var paymentDueDay: Int = 1
    var notes: String = ""
    var createdAt: Date = Date()
    /// Stored filename (not full path) inside ~/Documents/PropertyManager/Contracts/
    var pdfFilename: String? = nil

    @Relationship(inverse: \Apartment.contracts) var apartment: Apartment?
    @Relationship(inverse: \Tenant.contracts) var tenant: Tenant?

    @Relationship(deleteRule: .cascade) var rentPayments: [RentPayment] = []

    var type: ContractType {
        get { ContractType(rawValue: typeRaw) ?? .tenant }
        set { typeRaw = newValue.rawValue }
    }

    var status: ContractStatus {
        get { ContractStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var durationMonths: Int {
        let cal = Calendar.current
        let components = cal.dateComponents([.month, .day], from: startDate, to: endDate)
        let months = components.month ?? 0
        let days = components.day ?? 0
        return months == 0 && days > 0 ? 1 : max(months, 0)
    }

    var isExpired: Bool {
        status == .active && endDate < Date()
    }

    var isExpiringSoon: Bool {
        status == .active && endDate > Date() && endDate.timeIntervalSinceNow < 60 * 60 * 24 * 60
    }

    init(
        contractNumber: String,
        type: ContractType,
        startDate: Date,
        endDate: Date,
        rentAmount: Double,
        depositAmount: Double = 0,
        paymentDueDay: Int = 1,
        notes: String = ""
    ) {
        self.contractNumber = contractNumber
        self.typeRaw = type.rawValue
        self.statusRaw = ContractStatus.active.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.rentAmount = rentAmount
        self.depositAmount = depositAmount
        self.paymentDueDay = paymentDueDay
        self.notes = notes
        self.createdAt = Date()
    }
}
