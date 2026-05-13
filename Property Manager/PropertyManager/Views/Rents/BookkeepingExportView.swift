import SwiftUI
import SwiftData
import AppKit

// MARK: - Export type

enum BookkeepingExportType: String, CaseIterable {
    case rents  = "Rents (Mietvertrag)"
    case owners = "Owners (Verwaltungsvertrag)"
    case both   = "Rents & Owners"
}

// MARK: - Company short names

extension Company {
    var shortExportName: String {
        switch self {
        case .elfElfImmobilien:  return "1111"
        case .elfElfHolding:     return "1111 Holding"
        case .shermanImmobilien: return "Sherman"
        case .privat:            return "Privat"
        }
    }
}

// MARK: - Main View

struct BookkeepingExportView: View {
    @Query(sort: \Apartment.street) private var apartments: [Apartment]
    @Environment(\.dismiss) private var dismiss

    @State private var exportYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedCompanies: Set<Company> = Set(Company.allCases)
    @State private var exportType: BookkeepingExportType = .both
    @State private var exportError: String? = nil

    private let germanMonths = ["Jänner","Februar","März","April","Mai","Juni",
                                "Juli","August","September","Oktober","November","Dezember"]

    // Companies that actually have apartments in the store
    var availableCompanies: [Company] {
        let used = Set(apartments.map(\.company))
        return Company.allCases.filter { used.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Bookkeeping Export").font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Year
                    GroupBox("Year") {
                        YearPicker(label: "Export year", year: $exportYear)
                    }

                    // Export type
                    GroupBox("Data") {
                        Picker("", selection: $exportType) {
                            ForEach(BookkeepingExportType.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    // Companies
                    GroupBox("Companies") {
                        VStack(alignment: .leading, spacing: 6) {
                            if availableCompanies.isEmpty {
                                Text("No apartments found.").foregroundStyle(.secondary).font(.caption)
                            } else {
                                ForEach(availableCompanies, id: \.self) { company in
                                    Toggle(company.rawValue, isOn: Binding(
                                        get: { selectedCompanies.contains(company) },
                                        set: { on in
                                            if on { selectedCompanies.insert(company) }
                                            else  { selectedCompanies.remove(company) }
                                        }
                                    ))
                                }
                            }
                        }
                    }

                    // Sheet preview
                    GroupBox("Sheets that will be generated") {
                        let names = sheetNames()
                        if names.isEmpty {
                            Text("Select at least one company.").foregroundStyle(.secondary).font(.caption)
                        } else {
                            ForEach(names, id: \.self) { name in
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text").foregroundStyle(.accentColor).font(.caption)
                                    Text(name).font(.caption.bold())
                                }
                            }
                        }
                    }

                    if let err = exportError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(20)
            }

            Divider()
            HStack {
                Spacer()
                Button {
                    runExport()
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCompanies.isEmpty)
                .padding(16)
            }
        }
        .frame(width: 400, height: 520)
        .onAppear {
            selectedCompanies = Set(availableCompanies)
        }
    }

    // MARK: - Sheet name helpers

    private func sheetNames() -> [String] {
        var names: [String] = []
        let sorted = Company.allCases.filter { selectedCompanies.contains($0) }
        for company in sorted {
            switch exportType {
            case .rents:  names.append("\(company.shortExportName) Miete")
            case .owners: names.append("\(company.shortExportName) Verw.")
            case .both:
                names.append("\(company.shortExportName) Miete")
                names.append("\(company.shortExportName) Verw.")
            }
        }
        return names
    }

    // MARK: - Export

    private func runExport() {
        exportError = nil

        let sheets = buildSheets()
        guard !sheets.isEmpty else {
            exportError = "No data to export."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Bookkeeping Export"
        panel.nameFieldStringValue = "Buchhaltung_\(exportYear).xlsx"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try XLSXWriter.write(sheets: sheets, to: url)
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Sheet assembly

    private func buildSheets() -> [XLSXSheet] {
        var sheets: [XLSXSheet] = []
        let sorted = Company.allCases.filter { selectedCompanies.contains($0) }

        for company in sorted {
            switch exportType {
            case .rents:
                sheets.append(buildSheet(company: company, category: .mietvertrag))
            case .owners:
                sheets.append(buildSheet(company: company, category: .verwaltungsvertrag))
            case .both:
                sheets.append(buildSheet(company: company, category: .mietvertrag))
                sheets.append(buildSheet(company: company, category: .verwaltungsvertrag))
            }
        }
        return sheets
    }

    private func buildSheet(company: Company, category: ContractCategory) -> XLSXSheet {
        let isOwner = (category == .verwaltungsvertrag)
        let sheetName = isOwner ? "\(company.shortExportName) Verw." : "\(company.shortExportName) Miete"

        var rows: [[XLSXCell]] = []

        // Row 1: company name + year
        rows.append([
            .bold(company.rawValue),
            .empty, .empty, .empty,
            .bold(String(exportYear))
        ])
        // Row 2: blank
        rows.append([])

        // Group apartments by street, sorted ASC; within each group sort by apartmentNumber ASC
        let companyApts = apartments
            .filter { $0.company == company }
            .sorted {
                if $0.street != $1.street { return $0.street < $1.street }
                return $0.apartmentNumber.localizedStandardCompare($1.apartmentNumber) == .orderedAscending
            }

        let byStreet = Dictionary(grouping: companyApts) { $0.street }
        let streets = byStreet.keys.sorted()

        var hasMissingContracts = false

        for street in streets {
            let unitsForStreet = byStreet[street]!
                .sorted { $0.apartmentNumber.localizedStandardCompare($1.apartmentNumber) == .orderedAscending }

            // Building header row: street + IBAN (owner only)
            let ibanCell: XLSXCell = isOwner && !unitsForStreet[0].iban.isEmpty
                ? .string(unitsForStreet[0].iban)
                : .empty
            rows.append([.bold(street), .empty, .empty, ibanCell])

            // Column header row
            var headerRow: [XLSXCell] = [.empty, .bold("Saldo")]
            for month in germanMonths { headerRow.append(.bold(month)) }
            rows.append(headerRow)

            // Unit rows
            for apt in unitsForStreet {
                let relevantContracts = apt.contracts.filter { $0.category == category }
                let hasCon = !relevantContracts.isEmpty
                if !hasCon { hasMissingContracts = true }

                let label = "Top \(apt.apartmentNumber)\(hasCon ? "" : " *")"

                // Saldo: sum(amount - paidAmount) for payments with year < exportYear
                let saldo: Double = relevantContracts.flatMap(\.rentPayments)
                    .filter { $0.year < exportYear }
                    .reduce(0.0) { $0 + ($1.amount - $1.paidAmount) }

                var row: [XLSXCell] = [.string(label), hasCon ? .number(saldo) : .empty]

                for m in 1...12 {
                    let paid: Double = relevantContracts.flatMap(\.rentPayments)
                        .filter { $0.month == m && $0.year == exportYear }
                        .reduce(0.0) { $0 + $1.paidAmount }
                    row.append(hasCon ? .number(paid) : .empty)
                }

                rows.append(row)
            }

            // Spacer between buildings
            rows.append([])
        }

        // Footnote if any units had no contracts
        if hasMissingContracts {
            rows.append([.string("* No contract found — please update in app")])
        }

        return XLSXSheet(name: sheetName, rows: rows)
    }
}
