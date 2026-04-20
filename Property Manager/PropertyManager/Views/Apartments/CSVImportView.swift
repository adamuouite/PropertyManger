import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - CSV Import View

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    @State private var rows: [[String]] = []
    @State private var headers: [String] = []
    @State private var aptMap = ApartmentColumnMap()
    @State private var tenantMap = TenantColumnMap()
    @State private var step: ImportStep = .idle
    @State private var importedApts = 0
    @State private var importedTenants = 0
    @State private var errorMessage: String? = nil
    @State private var detectedDelimiter: Character = ","
    @State private var defaultType: ApartmentType = .standard
    @State private var defaultStatus: ApartmentStatus = .available
    @State private var defaultCountry = "Austria"
    @State private var defaultCompany: Company = .privat
    @State private var importTenants = true

    // Duplicate resolution state
    @State private var duplicateRows: [(rowIndex: Int, existing: Apartment)] = []
    @State private var duplicateActions: [Int: DuplicateAction] = [:]
    @State private var skippedDuplicates = 0

    enum ImportStep { case idle, preview, duplicates, done }
    enum DuplicateAction { case skip, update }

    private let minImportDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!
    func clampDate(_ d: Date) -> Date { d < minImportDate ? minImportDate : d }

    var previewRows: [[String]] { Array(rows.prefix(5)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(loc.t("csv.title"), systemImage: "square.and.arrow.down").font(.title2.bold())
                Spacer()
                Button(loc.t("common.close")) { dismiss() }.keyboardShortcut(.escape)
            }
            .padding(20)
            Divider()

            switch step {
            case .idle:       idleView
            case .preview:    previewView
            case .duplicates: duplicatesView
            case .done:       doneView
            }
        }
        .frame(width: 740, height: 580)
    }

    // MARK: Step 1 — Idle

    var idleView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Label(loc.t("csv.apt_columns"), systemImage: "building.2.fill")
                        .font(.headline).foregroundStyle(Color.accentColor)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(["street *", "gate / stiege", "apartment_number / top", "city", "postal_code", "country",
                                 "floor", "rooms", "area", "rent", "status", "type", "company", "notes"], id: \.self) { h in
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Color.accentColor)
                                Text(h).font(.caption.monospaced())
                                Spacer()
                            }
                        }
                    }

                    Divider()

                    Label(loc.t("csv.tenant_columns_desc"), systemImage: "person.2.fill")
                        .font(.headline).foregroundStyle(.purple)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(["tenant_first_name", "tenant_last_name", "tenant_email", "tenant_phone",
                                 "tenant_id", "tenant_number", "contract_start", "contract_end", "contract_rent"], id: \.self) { h in
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.purple)
                                Text(h).font(.caption.monospaced())
                                Spacer()
                            }
                        }
                    }
                    Text(.init(loc.t("csv.required_note")))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(16).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 12))

                // Download sample
                Button { downloadSampleCSV() } label: {
                    Label(loc.t("csv.download_sample"), systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)

                // Defaults
                GroupBox(loc.t("csv.defaults")) {
                    HStack(spacing: 16) {
                        Picker("Type", selection: $defaultType) {
                            ForEach(ApartmentType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.frame(width: 160)
                        Picker("Status", selection: $defaultStatus) {
                            ForEach(ApartmentStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.frame(width: 160)
                        TextField("Country", text: $defaultCountry).frame(width: 100)
                        Picker(loc.t("company.title"), selection: $defaultCompany) {
                            ForEach(Company.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.frame(width: 180)
                    }
                }

                Toggle(loc.t("csv.import_tenants"), isOn: $importTenants)
                    .padding(.horizontal, 4)

                Button { pickFile() } label: {
                    Label(loc.t("csv.choose_file"), systemImage: "doc.badge.plus").frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

                if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red).font(.caption)
                }
            }
            .padding(24)
        }
    }

    // MARK: Step 2 — Preview & Column Mapping

    var previewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                let delimDisplay = String(detectedDelimiter) == "\t" ? "tab" : String(detectedDelimiter)
                Label("\(rows.count) row\(rows.count == 1 ? "" : "s") found — delimiter: \"\(delimDisplay)\"",
                      systemImage: "tablecells.fill").font(.subheadline.bold())
                Spacer()
                Button(loc.t("csv.change_file")) { pickFile() }.buttonStyle(.bordered)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Apartment mapping
                    GroupBox {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                            GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            colPicker("Street *",         binding: $aptMap.street)
                            colPicker("Gate / Stiege",    binding: $aptMap.gate)
                            colPicker("Top / Apt. No.",   binding: $aptMap.apartmentNumber)
                            colPicker("City",             binding: $aptMap.city)
                            colPicker("Postal Code",      binding: $aptMap.postalCode)
                            colPicker("Country",          binding: $aptMap.country)
                            colPicker("Floor",            binding: $aptMap.floor)
                            colPicker("Rooms",            binding: $aptMap.rooms)
                            colPicker("Area (m²)",        binding: $aptMap.area)
                            colPicker("Rent (€)",         binding: $aptMap.rentPrice)
                            colPicker("Status",           binding: $aptMap.status)
                            colPicker("Type (WG/Std)",    binding: $aptMap.type)
                            colPicker(loc.t("csv.company"), binding: $aptMap.company)
                        }
                    } label: {
                        Label(loc.t("csv.apt_columns"), systemImage: "building.2.fill").font(.headline)
                    }

                    if importTenants {
                        GroupBox {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                                GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                colPicker("First Name",     binding: $tenantMap.firstName)
                                colPicker("Last Name",      binding: $tenantMap.lastName)
                                colPicker("Email",          binding: $tenantMap.email)
                                colPicker("Phone",          binding: $tenantMap.phone)
                                colPicker("ID / Passport",  binding: $tenantMap.idNumber)
                                colPicker("Tenant No.",     binding: $tenantMap.tenantNumber)
                                colPicker("Contract Start", binding: $tenantMap.contractStart)
                                colPicker("Contract End",   binding: $tenantMap.contractEnd)
                                colPicker("Contract Rent",  binding: $tenantMap.contractRent)
                                colPicker(loc.t("csv.contract_category"), binding: $tenantMap.contractCategory)
                            }
                        } label: {
                            Label(loc.t("csv.tenant_columns"), systemImage: "person.2.fill").font(.headline)
                                .foregroundStyle(.purple)
                        }
                    }

                    // Data preview
                    Text("\(loc.t("csv.preview")) (\(previewRows.count) rows):")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    ScrollView([.horizontal, .vertical]) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                ForEach(headers.indices, id: \.self) { i in
                                    Text(headers[i]).font(.caption.bold())
                                        .frame(width: 110, alignment: .leading).padding(6)
                                        .background(Color.accentColor.opacity(0.1))
                                }
                            }
                            Divider()
                            ForEach(previewRows.indices, id: \.self) { r in
                                HStack(spacing: 0) {
                                    ForEach(previewRows[r].indices, id: \.self) { c in
                                        Text(previewRows[r][c]).font(.caption)
                                            .frame(width: 110, alignment: .leading).padding(6)
                                            .background(r % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                                    }
                                }
                                Divider()
                            }
                        }
                    }
                    .background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxHeight: 150)
                }
                .padding(20)
            }

            Divider()
            HStack {
                Button(loc.t("common.cancel")) { dismiss() }
                Spacer()
                Button("\(loc.t("csv.import_now")) (\(rows.count))") { beginImport() }
                    .buttonStyle(.borderedProminent).disabled(aptMap.street == nil)
            }
            .padding(20)
        }
    }

    // MARK: Step 3 — Duplicate Resolution

    var duplicatesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(String(format: loc.t("csv.conflict_count"), duplicateRows.count),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold()).foregroundStyle(.orange)
                Spacer()
                Button(loc.t("csv.skip_all")) {
                    for d in duplicateRows { duplicateActions[d.rowIndex] = .skip }
                }.buttonStyle(.bordered)
                Button(loc.t("csv.update_all")) {
                    for d in duplicateRows { duplicateActions[d.rowIndex] = .update }
                }.buttonStyle(.bordered)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(duplicateRows.indices, id: \.self) { i in
                        let dup = duplicateRows[i]
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dup.existing.displayName).font(.subheadline.bold())
                                Text(dup.existing.fullAddress).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { duplicateActions[dup.rowIndex] ?? .skip },
                                set: { duplicateActions[dup.rowIndex] = $0 }
                            )) {
                                Text(loc.t("csv.duplicate_skip")).tag(DuplicateAction.skip)
                                Text(loc.t("csv.duplicate_update")).tag(DuplicateAction.update)
                            }
                            .pickerStyle(.segmented).frame(width: 180)
                        }
                        .padding(12)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }.padding(20)
            }
            Divider()
            HStack {
                Button(loc.t("common.cancel")) { dismiss() }
                Spacer()
                Button(loc.t("csv.confirm_import")) { importRows() }
                    .buttonStyle(.borderedProminent)
            }.padding(20)
        }
    }

    // MARK: Step 4 — Done

    var doneView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.green)
            Text(loc.t("csv.import_complete")).font(.largeTitle.bold())
            VStack(spacing: 6) {
                Label("\(importedApts) \(loc.t("csv.apartments_imported"))", systemImage: "building.2.fill")
                if importedTenants > 0 {
                    Label("\(importedTenants) \(loc.t("csv.tenants_imported"))", systemImage: "person.2.fill")
                        .foregroundStyle(.purple)
                }
                if skippedDuplicates > 0 {
                    Label(String(format: loc.t("csv.duplicates_skipped"), skippedDuplicates), systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
            Button(loc.t("common.close")) { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Column picker helper

    @ViewBuilder
    func colPicker(_ label: String, binding: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Picker("", selection: binding) {
                Text("—").tag(Optional<Int>.none)
                ForEach(headers.indices, id: \.self) { i in Text(headers[i]).tag(Optional(i)) }
            }.labelsHidden()
        }
    }

    // MARK: File picking

    private func downloadSampleCSV() {
        let sep = ";"
        let header = [
            "street", "gate", "apartment_number", "city", "postal_code", "country",
            "floor", "rooms", "area", "rent", "status", "type", "company", "notes",
            "tenant_first_name", "tenant_last_name", "tenant_email", "tenant_phone",
            "tenant_id", "tenant_number", "contract_start", "contract_end", "contract_rent", "contract_category"
        ].joined(separator: sep)

        let row1 = [
            "Gellertgasse 54A", "1", "6", "Wien", "1100", "Austria",
            "3", "2", "55.0", "750.00", "Rented", "Standard", "1111 Immobilien", "",
            "Max", "Mustermann", "max@example.com", "+43 660 1234567",
            "PA1234567", "M-001", "2025-01-01", "2026-12-31", "750.00", "Mietvertrag"
        ].joined(separator: sep)

        let row2 = [
            "Quellenstraße 12", "", "3", "Wien", "1100", "Austria",
            "1", "3", "72.5", "950.00", "Rented", "Standard", "Sherman Immobilien", "Balkon vorhanden",
            "Anna", "Müller", "anna.mueller@email.at", "+43 664 9876543",
            "ID98765", "M-002", "2024-06-01", "2026-05-31", "950.00", "Verwaltungsvertrag"
        ].joined(separator: sep)

        let row3 = [
            "Favoritenstraße 88", "2", "11", "Wien", "1100", "Austria",
            "4", "4", "95.0", "1200.00", "Available", "WG", "Privat", "WG-geeignet",
            "", "", "", "",
            "", "", "", "", "", ""
        ].joined(separator: sep)

        let content = "\u{FEFF}" + [header, row1, row2, row3].joined(separator: "\n")

        let panel = NSSavePanel()
        panel.title = loc.t("csv.download_sample")
        panel.nameFieldStringValue = "PropertyManager_Sample.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        try? content.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.title = loc.t("csv.choose_file")
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText,
                                     UTType(filenameExtension: "csv") ?? .data]
        panel.allowsMultipleSelection = false
        panel.message = loc.t("csv.panel_message")
        panel.prompt = loc.t("csv.panel_prompt")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        parseCSV(url: url)
    }

    private func parseCSV(url: URL) {
        errorMessage = nil

        // Try encodings in order; move UTF-16 before Windows-1252
        // because CP1252 accepts almost any byte sequence and would
        // absorb a UTF-16 file incorrectly.
        let encodings: [String.Encoding] = [.utf8, .utf16, .windowsCP1252, .isoLatin1]
        var raw: String?
        for enc in encodings {
            if let t = try? String(contentsOf: url, encoding: enc) { raw = t; break }
        }
        guard var content = raw else {
            errorMessage = loc.t("csv.error.read"); return
        }

        // Strip BOM (Excel UTF-8 exports prepend \uFEFF which breaks the first header)
        if content.hasPrefix("\u{FEFF}") {
            content = String(content.dropFirst())
        }

        // Normalize line endings to \n
        content = content.replacingOccurrences(of: "\r\n", with: "\n")
        content = content.replacingOccurrences(of: "\r",   with: "\n")

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = loc.t("csv.error.empty"); return
        }

        // Detect delimiter from the first line (before full parse)
        let firstLineEnd = content.firstIndex(of: "\n") ?? content.endIndex
        let headerLine = String(content[content.startIndex..<firstLineEnd])
        let candidates: [(Character, Int)] = [
            (",", headerLine.filter { $0 == "," }.count),
            (";", headerLine.filter { $0 == ";" }.count),
            ("\t", headerLine.filter { $0 == "\t" }.count)
        ]
        detectedDelimiter = candidates.max(by: { $0.1 < $1.1 })?.0 ?? ","

        // Parse entire file as a stream (handles multi-line quoted fields)
        let parsed = parseCSVContent(content, delimiter: detectedDelimiter)

        guard parsed.count >= 2 else {
            errorMessage = loc.t("csv.error.rows"); return
        }

        headers = parsed[0]
        rows    = Array(parsed.dropFirst())

        aptMap    = ApartmentColumnMap(); aptMap.autoMap(headers: headers)
        tenantMap = TenantColumnMap();    tenantMap.autoMap(headers: headers)
        step = .preview
    }

    /// Parses an entire CSV/TSV file as one stream, correctly handling
    /// RFC 4180 quoted fields including escaped quotes ("") and multi-line values.
    private func parseCSVContent(_ content: String, delimiter: Character) -> [[String]] {
        var results: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let char = content[i]

            if inQuotes {
                if char == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\"" {
                        currentField.append("\"")
                        i = content.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == delimiter {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else if char == "\n" {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        results.append(currentRow)
                    }
                    currentRow = []
                } else {
                    currentField.append(char)
                }
            }
            i = content.index(after: i)
        }

        // Flush last row
        currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            results.append(currentRow)
        }

        return results
    }

    // MARK: Import — Phase 1: Detect duplicates

    /// Called when user taps "Import Now" from preview. Detects duplicates and either
    /// proceeds directly (no dupes) or shows the resolution screen.
    private func beginImport() {
        let isoParser: DateFormatter = {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"; return f
        }()

        var found: [(rowIndex: Int, existing: Apartment)] = []
        for (idx, row) in rows.enumerated() {
            func col(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespaces)
            }
            let street = col(aptMap.street)
            let aptNum = col(aptMap.apartmentNumber)
            guard !street.isEmpty else { continue }

            let matches = (try? modelContext.fetch(
                FetchDescriptor<Apartment>(predicate: #Predicate { $0.street == street && $0.apartmentNumber == aptNum })
            )) ?? []
            if let existing = matches.first {
                found.append((rowIndex: idx, existing: existing))
                duplicateActions[idx] = .skip  // default
            }
        }

        duplicateRows = found
        if found.isEmpty {
            importRows()
        } else {
            step = .duplicates
        }
    }

    // MARK: Import — Phase 2: Execute

    private func importRows() {
        var aptCount = 0; var tenantCount = 0; var skipped = 0

        let isoParser: DateFormatter = {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"; return f
        }()
        let dotParser: DateFormatter = {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "dd.MM.yyyy"; return f
        }()
        let slashParser: DateFormatter = {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "dd/MM/yyyy"; return f
        }()
        func parseDate(_ s: String) -> Date? {
            isoParser.date(from: s) ?? dotParser.date(from: s) ?? slashParser.date(from: s)
        }

        for (idx, row) in rows.enumerated() {
            func col(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespaces)
            }

            let streetVal = col(aptMap.street)
            guard !streetVal.isEmpty else { continue }

            // Handle duplicates
            let aptNum = col(aptMap.apartmentNumber)
            let isDuplicate = duplicateRows.contains { $0.rowIndex == idx }
            if isDuplicate {
                let action = duplicateActions[idx] ?? .skip
                if action == .skip {
                    skipped += 1
                    continue
                } else {
                    // Update existing record
                    if let existing = duplicateRows.first(where: { $0.rowIndex == idx })?.existing {
                        let statusStr = col(aptMap.status)
                        if let s = ApartmentStatus.allCases.first(where: { $0.rawValue.lowercased() == statusStr.lowercased() }) {
                            existing.status = s
                        }
                        let companyStr = col(aptMap.company)
                        if let co = Company.allCases.first(where: { $0.rawValue.lowercased() == companyStr.lowercased() }) {
                            existing.company = co
                        }
                        let rentStr = col(aptMap.rentPrice).replacingOccurrences(of: ",", with: ".")
                        if let rent = Double(rentStr), rent > 0 { existing.rentPrice = rent }
                        let noteVal = col(aptMap.notes)
                        if !noteVal.isEmpty { existing.notes = noteVal }
                    }
                    continue
                }
            }

            let statusStr = col(aptMap.status)
            let parsedStatus = ApartmentStatus.allCases.first {
                $0.rawValue.lowercased() == statusStr.lowercased()
            } ?? defaultStatus

            let typeStr = col(aptMap.type).lowercased()
            let parsedType: ApartmentType = typeStr.contains("wg") ? .wg : defaultType

            let countryVal = col(aptMap.country)
            let companyStr = col(aptMap.company)
            let parsedCompany = Company.allCases.first {
                $0.rawValue.lowercased() == companyStr.lowercased()
            } ?? defaultCompany

            let apt = Apartment(
                street: streetVal,
                gate: col(aptMap.gate),
                apartmentNumber: aptNum,
                city: col(aptMap.city),
                postalCode: col(aptMap.postalCode),
                country: countryVal.isEmpty ? defaultCountry : countryVal,
                floor: Int(col(aptMap.floor)) ?? 0,
                rooms: Int(col(aptMap.rooms)) ?? 1,
                area: Double(col(aptMap.area).replacingOccurrences(of: ",", with: ".")) ?? 0,
                rentPrice: Double(col(aptMap.rentPrice).replacingOccurrences(of: ",", with: ".")) ?? 0,
                status: parsedStatus,
                type: parsedType,
                company: parsedCompany,
                notes: col(aptMap.notes)
            )
            modelContext.insert(apt)
            aptCount += 1

            // Create tenant + contract if columns present
            if importTenants {
                let firstName = col(tenantMap.firstName)
                let lastName  = col(tenantMap.lastName)
                let fullFirst = firstName.isEmpty ? col(tenantMap.fullName).components(separatedBy: " ").first ?? "" : firstName
                let fullLast  = lastName.isEmpty  ? col(tenantMap.fullName).components(separatedBy: " ").dropFirst().joined(separator: " ") : lastName

                if !fullFirst.isEmpty || !fullLast.isEmpty {
                    let tenant = Tenant(
                        firstName: fullFirst,
                        lastName: fullLast,
                        email: col(tenantMap.email),
                        phone: col(tenantMap.phone),
                        idNumber: col(tenantMap.idNumber),
                        tenantNumber: col(tenantMap.tenantNumber)
                    )
                    modelContext.insert(tenant)

                    let rentVal = Double(col(tenantMap.contractRent).replacingOccurrences(of: ",", with: ".")) ?? apt.rentPrice
                    let rawStart = parseDate(col(tenantMap.contractStart)) ?? Date()
                    let startDate = clampDate(rawStart)
                    let rawEnd = parseDate(col(tenantMap.contractEnd))
                        ?? Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? Date()
                    let endDate = clampDate(rawEnd)

                    let catStr = col(tenantMap.contractCategory).lowercased()
                    let category: ContractCategory = catStr.contains("verwalt") ? .verwaltungsvertrag : .mietvertrag

                    let contract = Contract(
                        contractNumber: "CTR-\(Int.random(in: 10000...99999))",
                        type: category,
                        startDate: startDate,
                        endDate: endDate,
                        rentAmount: rentVal
                    )
                    contract.apartment = apt
                    contract.tenant = tenant
                    modelContext.insert(contract)
                    tenantCount += 1
                }
            }
        }

        try? modelContext.save()
        importedApts = aptCount
        importedTenants = tenantCount
        skippedDuplicates = skipped
        step = .done
    }
}

// MARK: - Column Maps

struct ApartmentColumnMap {
    var street: Int? = nil
    var gate: Int? = nil
    var apartmentNumber: Int? = nil
    var city: Int? = nil
    var postalCode: Int? = nil
    var country: Int? = nil
    var floor: Int? = nil
    var rooms: Int? = nil
    var area: Int? = nil
    var rentPrice: Int? = nil
    var status: Int? = nil
    var type: Int? = nil
    var notes: Int? = nil
    var company: Int? = nil

    mutating func autoMap(headers: [String]) {
        for (i, h) in headers.enumerated() {
            let l = normalizeGerman(h.lowercased().trimmingCharacters(in: .whitespaces))
            switch l {
            case let s where s == "street" || s == "address" || s.contains("strasse") || s.contains("adresse"):
                street = i
            case let s where s.contains("gate") || s.contains("stiege") || s.contains("eingang") || s == "staircase":
                gate = i
            case let s where s == "top" || s == "apartment_number" || s.contains("apt") || s.contains("wohnung") || s.contains("nummer"):
                apartmentNumber = i
            case let s where s.contains("city") || s.contains("stadt") || s.contains("ort") || s == "town":
                city = i
            case let s where s.contains("postal") || s.contains("plz") || s.contains("zip"):
                postalCode = i
            case let s where s.contains("country") || s.contains("land"):
                country = i
            case let s where s.contains("floor") || s.contains("stock") || s.contains("etage"):
                floor = i
            case let s where s.contains("room") || s.contains("zimmer"):
                rooms = i
            case let s where s.contains("area") || s.contains("m2") || s.contains("sqm") || s.contains("flaeche"):
                area = i
            case let s where s.contains("rent") || s.contains("miete") || s.contains("price"):
                rentPrice = i
            case let s where s == "status":
                status = i
            case let s where s.contains("type") || s.contains("typ"):
                type = i
            case let s where s.contains("note") || s.contains("remark") || s.contains("bemerkung"):
                notes = i
            case let s where s.contains("company") || s.contains("unternehmen") || s.contains("firma") || s.contains("gesellschaft"):
                company = i
            default: break
            }
        }
    }

    /// Normalizes German umlauts and ß to ASCII equivalents for matching
    private func normalizeGerman(_ s: String) -> String {
        s.replacingOccurrences(of: "ä", with: "ae")
         .replacingOccurrences(of: "ö", with: "oe")
         .replacingOccurrences(of: "ü", with: "ue")
         .replacingOccurrences(of: "ß", with: "ss")
    }
}

struct TenantColumnMap {
    var firstName: Int? = nil
    var lastName: Int? = nil
    var fullName: Int? = nil
    var email: Int? = nil
    var phone: Int? = nil
    var idNumber: Int? = nil
    var tenantNumber: Int? = nil
    var contractStart: Int? = nil
    var contractEnd: Int? = nil
    var contractRent: Int? = nil
    var contractCategory: Int? = nil

    mutating func autoMap(headers: [String]) {
        for (i, h) in headers.enumerated() {
            let raw = h.lowercased().trimmingCharacters(in: .whitespaces)
            let l = normalizeGerman(raw)
            switch l {
            case let s where s.contains("first") && s.contains("name") || s == "vorname":
                firstName = i
            case let s where s.contains("last") && s.contains("name") || s == "nachname" || s == "familienname":
                lastName = i
            case let s where (s.contains("tenant") && s.contains("name")) || s == "tenant" || s == "mieter":
                fullName = i
            case let s where s.contains("email") || s.contains("e-mail") || s.contains("mail"):
                email = i
            case let s where s.contains("phone") || s.contains("tel") || s.contains("mobil") || s == "handy":
                phone = i
            case let s where s.contains("tenant_id") || s.contains("passport") || s.contains("ausweis") || s.contains("reisepass"):
                idNumber = i
            case let s where s.contains("tenant_number") || s.contains("tenant_no") || s.contains("mieternummer") || s.contains("mieter_nr") || s.contains("kundennummer"):
                tenantNumber = i
            case let s where s.contains("contract_start") || s.contains("mietbeginn") || s == "start" || s == "beginn" || s == "vertragsbeginn":
                contractStart = i
            case let s where s.contains("contract_end") || s.contains("mietende") || s == "end" || s == "ende" || s == "vertragsende":
                contractEnd = i
            case let s where s.contains("contract_rent") || s.contains("tenant_rent") || s == "mietzins":
                contractRent = i
            case let s where s.contains("contract_category") || s.contains("contract_type") || s == "vertragsart" || s == "kategorie":
                contractCategory = i
            default: break
            }
        }
    }

    private func normalizeGerman(_ s: String) -> String {
        s.replacingOccurrences(of: "ä", with: "ae")
         .replacingOccurrences(of: "ö", with: "oe")
         .replacingOccurrences(of: "ü", with: "ue")
         .replacingOccurrences(of: "��", with: "ss")
    }
}
