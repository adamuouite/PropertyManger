import SwiftData
import Foundation

enum ApartmentType: String, Codable, CaseIterable {
    case standard = "Standard"
    case wg = "WG"

    var icon: String {
        switch self {
        case .standard: return "house.fill"
        case .wg: return "person.3.fill"
        }
    }

    var label: String {
        switch self {
        case .standard: return "Standard Apartment"
        case .wg: return "Wohngemeinschaft (WG)"
        }
    }
}

enum ApartmentStatus: String, Codable, CaseIterable {
    case available = "Available"
    case rented = "Rented"
    case maintenance = "Maintenance"
    case reserved = "Reserved"

    var icon: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .rented: return "person.fill"
        case .maintenance: return "wrench.fill"
        case .reserved: return "clock.fill"
        }
    }
}

@Model
final class Apartment {
    // Address components
    var street: String = ""           // e.g. "Gellertgasse 54A"
    var gate: String = ""             // Stiege / Eingang (optional)
    var apartmentNumber: String = ""  // Top / Wohnungsnummer
    var city: String = ""
    var postalCode: String = ""
    var country: String = "Austria"

    // Details
    var floor: Int = 0
    var rooms: Int = 1
    var bathrooms: Int = 1
    var area: Double = 0
    var rentPrice: Double = 0
    var statusRaw: String = ApartmentStatus.available.rawValue
    var typeRaw: String = ApartmentType.standard.rawValue
    var maxTenants: Int = 1
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade) var contracts: [Contract] = []

    // MARK: - Computed

    /// Display name built from address components: "Gellertgasse 54A · Stiege 1 · Top 6"
    var displayName: String {
        var parts: [String] = []
        if !street.isEmpty { parts.append(street) }
        if !gate.isEmpty   { parts.append("Stiege \(gate)") }
        if !apartmentNumber.isEmpty { parts.append("Top \(apartmentNumber)") }
        return parts.isEmpty ? "Unnamed Unit" : parts.joined(separator: " · ")
    }

    /// Short label for list rows: "Top 6" or "Stiege 1 / Top 6"
    var shortLabel: String {
        var parts: [String] = []
        if !gate.isEmpty { parts.append("Stg. \(gate)") }
        if !apartmentNumber.isEmpty { parts.append("Top \(apartmentNumber)") }
        return parts.isEmpty ? street : parts.joined(separator: " / ")
    }

    var status: ApartmentStatus {
        get { ApartmentStatus(rawValue: statusRaw) ?? .available }
        set { statusRaw = newValue.rawValue }
    }

    var type: ApartmentType {
        get { ApartmentType(rawValue: typeRaw) ?? .standard }
        set { typeRaw = newValue.rawValue }
    }

    var isWG: Bool { type == .wg }

    var activeTenants: [Tenant] {
        var seen = Set<PersistentIdentifier>()
        return contracts
            .filter { $0.status == .active }
            .compactMap { $0.tenant }
            .filter { seen.insert($0.persistentModelID).inserted }
    }

    var occupancy: String {
        guard isWG else { return activeTenants.isEmpty ? "Vacant" : "Occupied" }
        return "\(activeTenants.count) / \(maxTenants) tenants"
    }

    var fullAddress: String {
        [street, gate.isEmpty ? nil : "Stiege \(gate)",
         apartmentNumber.isEmpty ? nil : "Top \(apartmentNumber)",
         postalCode, city, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    init(
        street: String,
        gate: String = "",
        apartmentNumber: String = "",
        city: String = "",
        postalCode: String = "",
        country: String = "Austria",
        floor: Int = 0,
        rooms: Int = 1,
        bathrooms: Int = 1,
        area: Double = 0,
        rentPrice: Double = 0,
        status: ApartmentStatus = .available,
        type: ApartmentType = .standard,
        maxTenants: Int = 1,
        notes: String = ""
    ) {
        self.street = street
        self.gate = gate
        self.apartmentNumber = apartmentNumber
        self.city = city
        self.postalCode = postalCode
        self.country = country
        self.floor = floor
        self.rooms = rooms
        self.bathrooms = bathrooms
        self.area = area
        self.rentPrice = rentPrice
        self.statusRaw = status.rawValue
        self.typeRaw = type.rawValue
        self.maxTenants = maxTenants
        self.notes = notes
        self.createdAt = Date()
    }
}
