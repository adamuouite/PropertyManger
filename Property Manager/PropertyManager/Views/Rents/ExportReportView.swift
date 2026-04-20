import SwiftUI
import SwiftData
import AppKit

// MARK: - Export Report View

struct ExportReportView: View {
    @Query(sort: \RentPayment.year, order: .reverse) private var allPayments: [RentPayment]
    @Query(sort: \Contract.contractNumber) private var contracts: [Contract]
    @Query(sort: \Apartment.street) private var apartments: [Apartment]
    @Query(sort: \Tenant.lastName) private var tenants: [Tenant]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    @State private var exportType: ExportType = .payments
    @State private var dateFrom: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var dateTo: Date = Date()
    @State private var statusFilter: PaymentStatus? = nil
    @State private var selectedApartment: Apartment? = nil
    @State private var selectedCompany: Company? = nil
    @State private var exportFormat: ExportFormat = .csv
    @State private var exportSuccess: String? = nil
    @State private var exportError: String? = nil

    enum ExportType: String, CaseIterable {
        case payments = "Rent Payments"
        case tenantLedger = "Tenant Ledger"
        case apartmentSummary = "Apartment Summary"
        case contractOverview = "Contract Overview"

        var icon: String {
            switch self {
            case .payments: return "eurosign.circle.fill"
            case .tenantLedger: return "person.2.fill"
            case .apartmentSummary: return "building.2.fill"
            case .contractOverview: return "doc.text.fill"
            }
        }
    }

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case tsv = "TSV (Tab-separated)"
    }

    var filteredPayments: [RentPayment] {
        allPayments.filter { p in
            let cal = Calendar.current
            var comps = DateComponents()
            comps.year = p.year; comps.month = p.month; comps.day = 1
            let paymentDate = cal.date(from: comps) ?? Date()
            let inRange = paymentDate >= dateFrom && paymentDate <= dateTo
            let matchStatus = statusFilter == nil || p.status == statusFilter
            let matchApt = selectedApartment == nil
                || p.contract?.apartment?.persistentModelID == selectedApartment?.persistentModelID
            let matchCompany = selectedCompany == nil
                || p.contract?.apartment?.company == selectedCompany
            return inRange && matchStatus && matchApt && matchCompany
        }
        .sorted { ($0.year, $0.month) < ($1.year, $1.month) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(loc.t("export.title")).font(.title2.bold())
                Spacer()
                Button(loc.t("common.close")) { dismiss() }.keyboardShortcut(.escape)
            }
            .padding(20)
            Divider()

            HStack(spacing: 0) {
                // Left: Options
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Report type
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loc.t("export.report_type")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(ExportType.allCases, id: \.self) { type in
                                Button {
                                    exportType = type
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: type.icon)
                                            .foregroundStyle(exportType == type ? .white : .secondary)
                                            .frame(width: 20)
                                        Text(localizedExportType(type))
                                            .font(.subheadline)
                                            .foregroundStyle(exportType == type ? .white : .primary)
                                        Spacer()
                                        if exportType == type {
                                            Image(systemName: "checkmark").font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(8)
                                    .background(exportType == type ? Color.accentColor : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        // Date range
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loc.t("export.date_range")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            DatePicker(loc.t("export.from"), selection: $dateFrom, displayedComponents: .date)
                                .font(.caption)
                            DatePicker(loc.t("export.to"), selection: $dateTo, displayedComponents: .date)
                                .font(.caption)
                        }

                        if exportType == .payments || exportType == .tenantLedger {
                            Divider()

                            // Filters
                            VStack(alignment: .leading, spacing: 8) {
                                Text(loc.t("export.filters")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)

                                Picker(loc.t("company.title"), selection: $selectedCompany) {
                                    Text(loc.t("company.all")).tag(Optional<Company>.none)
                                    ForEach(Company.allCases, id: \.self) { c in
                                        Text(c.rawValue).tag(Optional(c))
                                    }
                                }
                                .font(.caption)

                                Picker(loc.t("contract.apartment"), selection: $selectedApartment) {
                                    Text(loc.t("export.all_apartments")).tag(Optional<Apartment>.none)
                                    ForEach(apartments) { apt in
                                        Text(apt.displayName).tag(Optional(apt))
                                    }
                                }
                                .font(.caption)

                                Picker(loc.t("rent.status"), selection: $statusFilter) {
                                    Text(loc.t("export.all_statuses")).tag(Optional<PaymentStatus>.none)
                                    ForEach(PaymentStatus.allCases, id: \.self) { s in
                                        Text(s.rawValue).tag(Optional(s))
                                    }
                                }
                                .font(.caption)
                            }
                        }

                        Divider()

                        // Format
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loc.t("export.format")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Picker(loc.t("export.format"), selection: $exportFormat) {
                                ForEach(ExportFormat.allCases, id: \.self) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .font(.caption)
                        }
                    }
                    .padding(16)
                }
                .frame(width: 260)
                .background(.background)

                Divider()

                // Right: Preview
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(loc.t("export.preview"), systemImage: "eye").font(.headline)
                        Spacer()
                        Text(previewSummary).font(.caption).foregroundStyle(.secondary)
                    }

                    ScrollView([.horizontal, .vertical]) {
                        Text(generatePreview())
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        if let success = exportSuccess {
                            Label(success, systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(.green)
                        }
                        if let error = exportError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.red)
                        }
                        Spacer()
                        Button {
                            exportToFile()
                        } label: {
                            Label(loc.t("export.export_file"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 780, height: 560)
    }

    var previewSummary: String {
        switch exportType {
        case .payments:
            return "\(filteredPayments.count) \(loc.t("export.payment_records"))"
        case .tenantLedger:
            let tenantCount = Set(filteredPayments.compactMap { $0.contract?.tenant?.persistentModelID }).count
            return "\(tenantCount) \(loc.t("tenant.title")), \(filteredPayments.count) \(loc.t("rent.payments"))"
        case .apartmentSummary:
            return "\(apartments.count) \(loc.t("apt.title"))"
        case .contractOverview:
            return "\(contracts.count) \(loc.t("contract.title"))"
        }
    }

    func generatePreview() -> String {
        let lines = generateCSVLines()
        return lines.prefix(25).joined(separator: "\n")
            + (lines.count > 25 ? "\n... (\(lines.count - 25) \(loc.t("export.more_rows")))" : "")
    }

    func generateCSVLines() -> [String] {
        let sep = exportFormat == .csv ? ";" : "\t"

        switch exportType {
        case .payments:
            return generatePaymentLines(sep: sep)
        case .tenantLedger:
            return generateTenantLedgerLines(sep: sep)
        case .apartmentSummary:
            return generateApartmentSummaryLines(sep: sep)
        case .contractOverview:
            return generateContractOverviewLines(sep: sep)
        }
    }

    func localizedExportType(_ type: ExportType) -> String {
        switch type {
        case .payments: return loc.t("export.type.payments")
        case .tenantLedger: return loc.t("export.type.tenant_ledger")
        case .apartmentSummary: return loc.t("export.type.apartment_summary")
        case .contractOverview: return loc.t("export.type.contract_overview")
        }
    }

    func generatePaymentLines(sep: String) -> [String] {
        var lines: [String] = []
        lines.append([loc.t("export.h.month"), loc.t("export.h.year"), loc.t("export.h.company"),
                       loc.t("export.h.tenant"),
                       loc.t("export.h.tenant_no"), loc.t("export.h.apartment"), loc.t("export.h.contract"),
                       loc.t("export.h.direction"),
                       loc.t("export.h.amount_due"), loc.t("export.h.amount_paid"), loc.t("export.h.status"),
                       loc.t("export.h.due_date"), loc.t("export.h.paid_date"), loc.t("export.h.notes")]
            .joined(separator: sep))

        let df = DateFormatter.display

        for p in filteredPayments {
            let tenant = p.contract?.tenant
            let apt = p.contract?.apartment
            let row = [
                p.monthName,
                String(p.year),
                apt?.company.rawValue ?? "",
                tenant?.fullName ?? "",
                tenant?.tenantNumber ?? "",
                apt?.displayName ?? "",
                p.contract?.contractNumber ?? "",
                p.isExpense ? loc.t("rent.expense") : loc.t("rent.income"),
                String(format: "%.2f", p.amount),
                String(format: "%.2f", p.paidAmount),
                p.status.rawValue,
                df.string(from: p.dueDate),
                p.paidDate.map { df.string(from: $0) } ?? "",
                p.notes.replacingOccurrences(of: sep, with: " ")
            ]
            lines.append(row.joined(separator: sep))
        }
        return lines
    }

    func generateTenantLedgerLines(sep: String) -> [String] {
        var lines: [String] = []
        lines.append([loc.t("export.h.tenant"), loc.t("export.h.tenant_no"), loc.t("export.h.apartment"),
                       loc.t("export.h.total_due"), loc.t("export.h.total_paid"),
                       loc.t("export.h.balance"), loc.t("export.h.paid_count"),
                       loc.t("export.h.pending_count"), loc.t("export.h.overdue_count")]
            .joined(separator: sep))

        let grouped = Dictionary(grouping: filteredPayments) {
            $0.contract?.tenant?.persistentModelID
        }

        for (_, payments) in grouped.sorted(by: { ($0.value.first?.contract?.tenant?.lastName ?? "") < ($1.value.first?.contract?.tenant?.lastName ?? "") }) {
            let tenant = payments.first?.contract?.tenant
            let apt = payments.first?.contract?.apartment
            let totalDue = payments.reduce(0.0) { $0 + $1.amount }
            let totalPaid = payments.reduce(0.0) { $0 + $1.paidAmount }
            let row = [
                tenant?.fullName ?? "Unknown",
                tenant?.tenantNumber ?? "",
                apt?.displayName ?? "",
                String(format: "%.2f", totalDue),
                String(format: "%.2f", totalPaid),
                String(format: "%.2f", totalDue - totalPaid),
                String(payments.filter { $0.status == .paid }.count),
                String(payments.filter { $0.status == .pending }.count),
                String(payments.filter { $0.status == .overdue }.count)
            ]
            lines.append(row.joined(separator: sep))
        }
        return lines
    }

    func generateApartmentSummaryLines(sep: String) -> [String] {
        var lines: [String] = []
        lines.append([loc.t("export.h.apartment"), loc.t("export.h.street"), loc.t("export.h.gate"),
                       loc.t("export.h.top"), loc.t("export.h.city"), loc.t("export.h.postal"),
                       loc.t("export.h.type"), loc.t("export.h.company"), loc.t("export.h.status"), loc.t("export.h.rooms"),
                       loc.t("export.h.area"), loc.t("export.h.monthly_rent"),
                       loc.t("export.h.active_tenants"), loc.t("export.h.total_contracts"),
                       loc.t("export.h.total_received")]
            .joined(separator: sep))

        for apt in apartments {
                   let paidPayments: [RentPayment] = apt.contracts
                       .flatMap { $0.rentPayments }
                       .filter { $0.status == .paid || $0.status == .partial }
                   let totalReceived: Double = paidPayments.reduce(0.0) { $0 + $1.paidAmount }
            let row = [
                apt.displayName,
                apt.street,
                apt.gate,
                apt.apartmentNumber,
                apt.city,
                apt.postalCode,
                apt.type.rawValue, apt.company.rawValue,
                apt.status.rawValue,
                String(apt.rooms),
                String(format: "%.1f", apt.area),
                String(format: "%.2f", apt.rentPrice),
                String(apt.activeTenants.count),
                String(apt.contracts.count),
                String(format: "%.2f", totalReceived)
            ]
            lines.append(row.joined(separator: sep))
        }
        return lines
    }

    func generateContractOverviewLines(sep: String) -> [String] {
        var lines: [String] = []
        let df = DateFormatter.display

        lines.append([loc.t("export.h.contract_no"), loc.t("export.h.category"), loc.t("export.h.company"), loc.t("export.h.status"),
                       loc.t("export.h.apartment"), loc.t("export.h.tenant"), loc.t("export.h.tenant_no"),
                       loc.t("export.h.start_date"), loc.t("export.h.end_date"), loc.t("export.h.monthly_rent"),
                       loc.t("export.h.deposit"), loc.t("export.h.duration"),
                       loc.t("export.h.payments_count"), loc.t("export.h.total_received"),
                       loc.t("export.h.has_pdf")]
            .joined(separator: sep))

        for c in contracts {
            let totalReceived = c.rentPayments
                .filter { $0.status == .paid || $0.status == .partial }
                .reduce(0.0) { $0 + $1.paidAmount }
            let row = [
                c.contractNumber,
                c.category.rawValue, c.apartment?.company.rawValue ?? "",
                c.status.rawValue,
                c.apartment?.displayName ?? "",
                c.tenant?.fullName ?? "",
                c.tenant?.tenantNumber ?? "",
                df.string(from: c.startDate),
                df.string(from: c.endDate),
                String(format: "%.2f", c.rentAmount),
                String(format: "%.2f", c.depositAmount),
                String(c.durationMonths),
                String(c.rentPayments.count),
                String(format: "%.2f", totalReceived),
                c.pdfFilename != nil ? loc.t("common.yes") : loc.t("common.no")
            ]
            lines.append(row.joined(separator: sep))
        }
        return lines
    }

    func exportToFile() {
        exportSuccess = nil
        exportError = nil

        let lines = generateCSVLines()
        guard lines.count > 1 else {
            exportError = loc.t("export.no_data")
            return
        }

        let content = lines.joined(separator: "\n")
        let ext = exportFormat == .csv ? "csv" : "tsv"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        let typeName = localizedExportType(exportType).replacingOccurrences(of: " ", with: "_")
        let defaultName = "\(typeName)_\(timestamp).\(ext)"

        let panel = NSSavePanel()
        panel.title = "\(loc.t("common.export")) \(localizedExportType(exportType))"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = exportFormat == .csv
            ? [.commaSeparatedText] : [.tabSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            // Write with UTF-8 BOM for Excel compatibility
            let bom = "\u{FEFF}"
            try (bom + content).write(to: url, atomically: true, encoding: .utf8)
            exportSuccess = String(format: loc.t("export.success"), lines.count - 1, url.lastPathComponent)

            // Also save a copy to Reports folder
            let reportsCopy = PDFManager.reportsFolder.appendingPathComponent(url.lastPathComponent)
            try? (bom + content).write(to: reportsCopy, atomically: true, encoding: .utf8)
        } catch {
            exportError = "\(loc.t("export.export_failed")) \(error.localizedDescription)"
        }
    }
}
