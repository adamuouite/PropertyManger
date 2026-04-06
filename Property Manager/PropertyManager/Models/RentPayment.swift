import SwiftData
import Foundation

enum PaymentStatus: String, Codable, CaseIterable {
    case paid = "Paid"
    case pending = "Pending"
    case overdue = "Overdue"
    case partial = "Partial"

    var icon: String {
        switch self {
        case .paid: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .partial: return "minus.circle.fill"
        }
    }
}

@Model
final class RentPayment {
    var amount: Double = 0
    var paidAmount: Double = 0
    var dueDate: Date = Date()
    var paidDate: Date? = nil
    var statusRaw: String = PaymentStatus.pending.rawValue
    var month: Int = 1
    var year: Int = 2026
    var notes: String = ""

    @Relationship(inverse: \Contract.rentPayments) var contract: Contract?

    var status: PaymentStatus {
        get { PaymentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var monthName: String {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.month = month
        comps.year = year
        comps.day = 1
        let date = cal.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    init(amount: Double, dueDate: Date, month: Int, year: Int = Calendar.current.component(.year, from: Date()), notes: String = "") {
        self.amount = amount
        self.paidAmount = 0
        self.dueDate = dueDate
        self.paidDate = nil
        self.statusRaw = PaymentStatus.pending.rawValue
        self.month = month
        self.year = year
        self.notes = notes
    }
}
