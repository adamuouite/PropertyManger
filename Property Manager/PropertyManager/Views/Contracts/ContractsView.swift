import SwiftUI
import SwiftData

// MARK: - Main View

struct ContractsView: View {
    @Query(sort: \Contract.createdAt, order: .reverse) private var contracts: [Contract]
    @Query(sort: \Apartment.street) private var apartments: [Apartment]
    @Query(sort: \Tenant.lastName) private var tenants: [Tenant]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.loc) var loc
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedContract: Contract?
    @State private var showAdd = false
    @State private var editContract: Contract?
    @State private var deleteTarget: Contract?
    @State private var typeFilter: ContractType? = nil
    @State private var statusFilter: ContractStatus? = nil
    @State private var search = ""

    var canEdit: Bool { authManager.canPerform(.manageContracts) }

    var filtered: [Contract] {
        contracts.filter { c in
            let matchSearch = search.isEmpty
                || c.contractNumber.localizedCaseInsensitiveContains(search)
                || (c.apartment?.displayName ?? "").localizedCaseInsensitiveContains(search)
                || (c.tenant?.fullName ?? "").localizedCaseInsensitiveContains(search)
            let matchType = typeFilter == nil || c.type == typeFilter
            let matchStatus = statusFilter == nil || c.status == statusFilter
            return matchSearch && matchType && matchStatus
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Left Pane
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(loc.t("contract.search"), text: $search).textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            FilterChip(label: loc.t("contract.all_types"), selected: typeFilter == nil) { typeFilter = nil }
                            ForEach(ContractType.allCases, id: \.self) { t in
                                FilterChip(label: t.rawValue, selected: typeFilter == t) { typeFilter = t }
                            }
                            Divider().frame(height: 16)
                            FilterChip(label: loc.t("contract.all_status"), selected: statusFilter == nil) { statusFilter = nil }
                            ForEach(ContractStatus.allCases, id: \.self) { s in
                                FilterChip(label: s.rawValue, selected: statusFilter == s) { statusFilter = s }
                            }
                        }
                    }
                }
                .padding(10)

                Divider()

                List(filtered, selection: $selectedContract) { c in
                    ContractRow(contract: c).tag(c)
                }
                .listStyle(.plain)
            }
            .frame(width: 300)

            Divider()

            // MARK: Right Pane
            Group {
                if let c = selectedContract {
                    ContractDetail(contract: c, canEdit: canEdit,
                                   onEdit: { editContract = c },
                                   onDelete: { deleteTarget = c })
                } else {
                    ContentUnavailableView(loc.t("contract.no_selection"), systemImage: "doc.text",
                                          description: Text(loc.t("contract.no_selection_desc")))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(loc.t("contract.title"))
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Label(loc.t("contract.add"), systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddEditContractView(contract: nil, apartments: apartments, tenants: tenants) }
        .sheet(item: $editContract) { c in AddEditContractView(contract: c, apartments: apartments, tenants: tenants) }
        .confirmationDialog("\(loc.t("common.delete")) \(deleteTarget?.contractNumber ?? "")?",
                            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                if let c = deleteTarget {
                    if selectedContract == c { selectedContract = nil }
                    modelContext.delete(c); try? modelContext.save(); deleteTarget = nil
                }
            }
        } message: { Text(loc.t("contract.delete_msg")) }
    }
}

// MARK: - Row

struct ContractRow: View {
    let contract: Contract
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(contract.contractNumber, systemImage: contract.type.icon)
                    .font(.headline)
                Spacer()
                StatusBadge(text: contract.status.rawValue, icon: contract.status.icon)
            }
            if let apt = contract.apartment {
                Text(apt.displayName).font(.caption).foregroundStyle(.secondary)
            }
            if let tenant = contract.tenant {
                Text(tenant.fullName).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(contract.rentAmount.formatted(.currency(code: "EUR")) + " " + loc.t("common.per_month"))
                    .font(.caption.bold()).foregroundStyle(.green)
                Spacer()
                Text("\(contract.startDate.formatted(date: .abbreviated, time: .omitted)) – \(contract.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct ContractDetail: View {
    let contract: Contract
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.loc) var loc
    @State private var pdfError: String? = nil
    @State private var showRemovePDFConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(contract.contractNumber, systemImage: contract.type.icon)
                            .font(.largeTitle.bold())
                        Text("\(loc.t("contract.type")): \(contract.type.rawValue)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(text: contract.status.rawValue, icon: contract.status.icon, large: true)
                }

                // Metrics
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    MetricCard(label: loc.t("apt.monthly_rent"), value: contract.rentAmount.formatted(.currency(code: "EUR")), icon: "eurosign.circle.fill", color: .green)
                    MetricCard(label: loc.t("contract.deposit"), value: contract.depositAmount.formatted(.currency(code: "EUR")), icon: "lock.fill", color: .orange)
                    MetricCard(label: loc.t("contract.duration"), value: "\(contract.durationMonths) \(loc.t("contract.months"))", icon: "calendar", color: .blue)
                    MetricCard(label: loc.t("contract.due_day"), value: "Day \(contract.paymentDueDay)", icon: "clock.fill", color: .purple)
                }

                // MARK: PDF Attachment Section
                VStack(alignment: .leading, spacing: 10) {
                    Label(loc.t("contract.pdf"), systemImage: "doc.fill")
                        .font(.headline)

                    if let filename = contract.pdfFilename, PDFManager.exists(filename: filename) {
                        // PDF is attached
                        HStack(spacing: 12) {
                            Image(systemName: "doc.richtext.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.red)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(filename)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(PDFManager.fileSize(filename: filename))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(PDFManager.url(for: filename).deletingLastPathComponent().path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }

                            Spacer()

                            VStack(spacing: 6) {
                                Button {
                                    PDFManager.open(filename: filename)
                                } label: {
                                    Label(loc.t("common.open"), systemImage: "eye")
                                        .frame(minWidth: 80)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)

                                Button {
                                    PDFManager.revealInFinder(filename: filename)
                                } label: {
                                    Label(loc.t("contract.show_finder"), systemImage: "folder")
                                        .frame(minWidth: 80)
                                }
                                .buttonStyle(.bordered)

                                if canEdit {
                                    Button(role: .destructive) {
                                        showRemovePDFConfirm = true
                                    } label: {
                                        Label(loc.t("common.remove"), systemImage: "trash")
                                            .frame(minWidth: 80)
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    } else {
                        // No PDF attached
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.title)
                                .foregroundStyle(.secondary.opacity(0.5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc.t("contract.no_pdf"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(loc.t("contract.no_pdf_desc"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                            Spacer()
                            if canEdit {
                                Button {
                                    attachPDF()
                                } label: {
                                    Label(loc.t("contract.attach_pdf"), systemImage: "paperclip")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(14)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .foregroundStyle(.secondary.opacity(0.3))
                        )
                    }

                    if let err = pdfError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .confirmationDialog(loc.t("contract.remove_pdf_confirm"), isPresented: $showRemovePDFConfirm, titleVisibility: .visible) {
                    Button(loc.t("common.remove"), role: .destructive) {
                        if let filename = contract.pdfFilename {
                            PDFManager.delete(filename: filename)
                            contract.pdfFilename = nil
                            try? modelContext.save()
                        }
                    }
                } message: {
                    Text(loc.t("contract.remove_pdf_msg"))
                }

                // Linked Apartment
                if let apt = contract.apartment {
                    InfoSection(title: loc.t("contract.linked_apartment"), icon: "building.2.fill") {
                        InfoRow(label: loc.t("apt.display_name"), value: apt.displayName)
                        InfoRow(label: loc.t("apt.address"), value: apt.fullAddress)
                        InfoRow(label: loc.t("apt.rooms"), value: "\(apt.rooms) \(loc.t("apt.rooms")), \(apt.bathrooms) \(loc.t("apt.bathrooms"))")
                    }
                }

                // Linked Tenant
                if let tenant = contract.tenant {
                    InfoSection(title: loc.t("contract.linked_tenant"), icon: "person.fill") {
                        InfoRow(label: loc.t("apt.display_name"), value: tenant.fullName)
                        InfoRow(label: loc.t("tenant.email"), value: tenant.email)
                        InfoRow(label: loc.t("tenant.phone"), value: tenant.phone)
                    }
                }

                // Dates
                InfoSection(title: loc.t("contract.period"), icon: "calendar") {
                    InfoRow(label: loc.t("contract.start"), value: contract.startDate.formatted(date: .long, time: .omitted))
                    InfoRow(label: loc.t("contract.end"), value: contract.endDate.formatted(date: .long, time: .omitted))
                    if contract.isExpiringSoon {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(loc.t("contract.expiring_soon")).font(.caption).foregroundStyle(.orange)
                        }
                    }
                }

                // Payments summary
                if !contract.rentPayments.isEmpty {
                    InfoSection(title: loc.t("contract.payment_history") + " (\(contract.rentPayments.count) records)", icon: "list.bullet") {
                        ForEach(contract.rentPayments.sorted { ($0.year, $0.month) > ($1.year, $1.month) }.prefix(6)) { p in
                            HStack {
                                Text(p.monthName).font(.caption)
                                Spacer()
                                StatusBadge(text: p.status.rawValue, icon: p.status.icon)
                                Text(p.amount.formatted(.currency(code: "EUR"))).font(.caption.bold())
                            }
                        }
                    }
                }

                if !contract.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(loc.t("common.notes"), systemImage: "note.text").font(.headline)
                        Text(contract.notes).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
        }
        .toolbar {
            if canEdit {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { attachPDF() } label: { Label(loc.t("contract.attach_pdf"), systemImage: "paperclip") }
                        .help(loc.t("contract.attach_pdf_help"))
                    Button(action: onEdit) { Label(loc.t("common.edit"), systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) { Label(loc.t("common.delete"), systemImage: "trash") }
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func attachPDF() {
        pdfError = nil
        guard let sourceURL = PDFManager.pickPDF() else { return }
        do {
            if let old = contract.pdfFilename { PDFManager.delete(filename: old) }
            let filename = try PDFManager.attachPDF(from: sourceURL, contractNumber: contract.contractNumber)
            contract.pdfFilename = filename
            try? modelContext.save()
        } catch {
            pdfError = "\(loc.t("contract.attach_failed")) \(error.localizedDescription)"
        }
    }
}

// MARK: - Add/Edit Form

struct AddEditContractView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    let contract: Contract?
    let apartments: [Apartment]
    let tenants: [Tenant]

    @State private var contractNumber = ""
    @State private var type: ContractType = .tenant
    @State private var status: ContractStatus = .active
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var rentAmount = 0.0
    @State private var depositAmount = 0.0
    @State private var paymentDueDay = 1
    @State private var selectedApartment: Apartment?
    @State private var selectedTenant: Tenant?
    @State private var notes = ""

    var isEditing: Bool { contract != nil }
    var isValid: Bool { !contractNumber.isEmpty && rentAmount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.t("contract.edit") : loc.t("contract.add"))
                    .font(.title2.bold())
                Spacer()
                Button(loc.t("common.cancel")) { dismiss() }.keyboardShortcut(.escape)
                Button(isEditing ? loc.t("common.save") : loc.t("common.add")) { save() }
                    .buttonStyle(.borderedProminent).disabled(!isValid)
            }
            .padding(20)
            Divider()

            ScrollView {
                Form {
                    Section(loc.t("contract.title")) {
                        TextField(loc.t("contract.number") + " *", text: $contractNumber)
                        Picker(loc.t("contract.type"), selection: $type) {
                            ForEach(ContractType.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                        }
                        Picker(loc.t("contract.status"), selection: $status) {
                            ForEach(ContractStatus.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                        }
                    }

                    Section(loc.t("contract.dates")) {
                        DatePicker(loc.t("contract.start"), selection: $startDate, displayedComponents: .date)
                        DatePicker(loc.t("contract.end"), selection: $endDate, displayedComponents: .date)
                    }

                    Section(loc.t("contract.financials")) {
                        HStack {
                            Text(loc.t("contract.monthly_rent") + " *")
                            Spacer()
                            TextField("0", value: $rentAmount, format: .number)
                                .frame(width: 100).multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text(loc.t("contract.deposit"))
                            Spacer()
                            TextField("0", value: $depositAmount, format: .number)
                                .frame(width: 100).multilineTextAlignment(.trailing)
                        }
                        Stepper("\(loc.t("contract.due_day")): \(paymentDueDay)", value: $paymentDueDay, in: 1...28)
                    }

                    Section(loc.t("contract.link_apartment")) {
                        Picker(loc.t("contract.apartment"), selection: $selectedApartment) {
                            Text(loc.t("common.none")).tag(Optional<Apartment>.none)
                            ForEach(apartments) { apt in
                                Text(apt.displayName).tag(Optional(apt))
                            }
                        }
                    }

                    Section(loc.t("contract.link_tenant")) {
                        Picker(loc.t("contract.tenant"), selection: $selectedTenant) {
                            Text(loc.t("common.none")).tag(Optional<Tenant>.none)
                            ForEach(tenants) { t in
                                Text(t.fullName).tag(Optional(t))
                            }
                        }
                    }

                    Section(loc.t("common.notes")) {
                        TextEditor(text: $notes).frame(minHeight: 60)
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(width: 540, height: 600)
        .onAppear {
            if let c = contract {
                contractNumber = c.contractNumber; type = c.type; status = c.status
                startDate = c.startDate; endDate = c.endDate; rentAmount = c.rentAmount
                depositAmount = c.depositAmount; paymentDueDay = c.paymentDueDay
                selectedApartment = c.apartment; selectedTenant = c.tenant; notes = c.notes
            } else {
                contractNumber = "CTR-\(Int.random(in: 10000...99999))"
            }
        }
    }

    private func save() {
        if let c = contract {
            c.contractNumber = contractNumber; c.type = type; c.status = status
            c.startDate = startDate; c.endDate = endDate; c.rentAmount = rentAmount
            c.depositAmount = depositAmount; c.paymentDueDay = paymentDueDay
            c.apartment = selectedApartment; c.tenant = selectedTenant; c.notes = notes
        } else {
            let c = Contract(contractNumber: contractNumber, type: type,
                             startDate: startDate, endDate: endDate,
                             rentAmount: rentAmount, depositAmount: depositAmount,
                             paymentDueDay: paymentDueDay, notes: notes)
            c.apartment = selectedApartment; c.tenant = selectedTenant; c.status = status
            modelContext.insert(c)
        }
        try? modelContext.save(); dismiss()
    }
}

// MARK: - Shared helpers

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            VStack(spacing: 0) {
                content()
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).font(.caption.bold())
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        Divider().padding(.leading, 12)
    }
}
