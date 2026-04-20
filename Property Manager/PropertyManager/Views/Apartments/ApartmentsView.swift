import SwiftUI
import SwiftData

// MARK: - Main View

struct ApartmentsView: View {
    @Query(sort: \Apartment.street) private var apartments: [Apartment]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.loc) var loc

    @State private var selectedApartment: Apartment?
    @State private var multiSelection = Set<PersistentIdentifier>()
    @State private var isSelectMode = false
    @State private var showAdd = false
    @State private var editApartment: Apartment?
    @State private var deleteTarget: Apartment?
    @State private var showBulkDeleteConfirm = false
    @State private var showImport = false
    @State private var statusFilter: ApartmentStatus? = nil
    @State private var typeFilter: ApartmentType? = nil
    @State private var companyFilter: Company? = nil
    @State private var search = ""

    var canEdit: Bool { authManager.canPerform(.manageApartments) }

    var filtered: [Apartment] {
        apartments.filter { apt in
            let matchSearch = search.isEmpty
                || apt.street.localizedCaseInsensitiveContains(search)
                || apt.displayName.localizedCaseInsensitiveContains(search)
                || apt.city.localizedCaseInsensitiveContains(search)
                || apt.apartmentNumber.localizedCaseInsensitiveContains(search)
            let matchStatus  = statusFilter == nil  || apt.status == statusFilter
            let matchType    = typeFilter == nil    || apt.type == typeFilter
            let matchCompany = companyFilter == nil || apt.company == companyFilter
            return matchSearch && matchStatus && matchType && matchCompany
        }
    }

    var selectedApartments: [Apartment] {
        apartments.filter { multiSelection.contains($0.persistentModelID) }
    }

    var body: some View {
        HSplitView {
            // MARK: Left Pane
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 6) {
                    if isSelectMode {
                        Button {
                            multiSelection = multiSelection.count == filtered.count
                                ? [] : Set(filtered.map { $0.persistentModelID })
                        } label: {
                            Text(multiSelection.count == filtered.count ? loc.t("common.deselect_all") : loc.t("common.select_all"))
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        if !multiSelection.isEmpty {
                            Button(role: .destructive) { showBulkDeleteConfirm = true } label: {
                                Label("\(loc.t("common.delete")) (\(multiSelection.count))", systemImage: "trash.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent).tint(.red)
                        }
                        Button(loc.t("common.done")) { isSelectMode = false; multiSelection.removeAll() }
                            .buttonStyle(.bordered).font(.caption)
                    } else {
                        if canEdit {
                            Button { isSelectMode = true } label: {
                                Image(systemName: "checkmark.circle")
                            }.help(loc.t("apt.select_mode"))
                            Button { showImport = true } label: {
                                Image(systemName: "square.and.arrow.down")
                            }.help(loc.t("apt.import"))
                        }
                        Spacer()
                        Text("\(filtered.count) unit\(filtered.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(loc.t("apt.search"), text: $search).textFieldStyle(.plain)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(8).background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 10)

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        FilterChip(label: loc.t("common.all"), selected: typeFilter == nil && statusFilter == nil && companyFilter == nil) {
                            typeFilter = nil; statusFilter = nil; companyFilter = nil
                        }
                        Divider().frame(height: 16)
                        ForEach(Company.allCases, id: \.self) { co in
                            FilterChip(label: co.rawValue, selected: companyFilter == co) {
                                companyFilter = companyFilter == co ? nil : co
                            }
                        }
                        Divider().frame(height: 16)
                        FilterChip(label: "WG", selected: typeFilter == .wg) {
                            typeFilter = typeFilter == .wg ? nil : .wg
                        }
                        FilterChip(label: "Standard", selected: typeFilter == .standard) {
                            typeFilter = typeFilter == .standard ? nil : .standard
                        }
                        Divider().frame(height: 16)
                        ForEach(ApartmentStatus.allCases, id: \.self) { s in
                            FilterChip(label: s.rawValue, selected: statusFilter == s) {
                                statusFilter = statusFilter == s ? nil : s
                            }
                        }
                    }.padding(.horizontal, 10)
                }.padding(.vertical, 6)

                Divider()

                // List
                if isSelectMode {
                    List(selection: $multiSelection) {
                        ForEach(filtered) { apt in
                            HStack(spacing: 8) {
                                Image(systemName: multiSelection.contains(apt.persistentModelID)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(multiSelection.contains(apt.persistentModelID)
                                                     ? Color.accentColor : Color.secondary)
                                    .onTapGesture {
                                        if multiSelection.contains(apt.persistentModelID) {
                                            multiSelection.remove(apt.persistentModelID)
                                        } else {
                                            multiSelection.insert(apt.persistentModelID)
                                        }
                                    }
                                ApartmentRow(apartment: apt)
                            }
                        }
                    }.listStyle(.plain)
                } else {
                    List(filtered, selection: $selectedApartment) { apt in
                        ApartmentRow(apartment: apt).tag(apt)
                    }.listStyle(.plain)
                }
            }
            .frame(minWidth: 220, maxWidth: 360).background(.background)

            // Right Pane
            Group {
                if isSelectMode {
                    SelectionSummaryView(
                        title: "\(selectedApartments.count) \(loc.t("apt.title"))",
                        items: selectedApartments,
                        nameFor: { $0.displayName },
                        emptyHint: loc.t("apt.select_hint"),
                        softActionLabel: nil, softAction: nil,
                        deleteActionLabel: "\(loc.t("common.delete")) \(selectedApartments.count) \(loc.t("apt.title"))",
                        deleteAction: { showBulkDeleteConfirm = true }
                    )
                } else if let apt = selectedApartment {
                    ApartmentDetail(apartment: apt, canEdit: canEdit,
                                    onEdit: { editApartment = apt }, onDelete: { deleteTarget = apt })
                } else {
                    ContentUnavailableView(loc.t("apt.no_selection"), systemImage: "building.2",
                                          description: Text(loc.t("apt.no_selection_desc")))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(loc.t("apt.title"))
        .toolbar {
            if canEdit && !isSelectMode {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Label(loc.t("apt.add"), systemImage: "plus") }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddEditApartmentView(apartment: nil) }
        .sheet(item: $editApartment) { apt in AddEditApartmentView(apartment: apt) }
        .sheet(isPresented: $showImport) { CSVImportView() }
        .confirmationDialog("\(loc.t("common.delete")) \(deleteTarget?.displayName ?? "")?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                if let apt = deleteTarget {
                    if selectedApartment == apt { selectedApartment = nil }
                    modelContext.delete(apt); try? modelContext.save(); deleteTarget = nil
                }
            }
        } message: { Text(loc.t("apt.delete_msg")) }
        .confirmationDialog("\(loc.t("common.delete")) \(multiSelection.count) \(loc.t("apt.title"))?",
            isPresented: $showBulkDeleteConfirm, titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                for apt in selectedApartments {
                    if selectedApartment == apt { selectedApartment = nil }
                    modelContext.delete(apt)
                }
                try? modelContext.save(); multiSelection.removeAll(); isSelectMode = false
            }
        } message: { Text(loc.t("apt.bulk_delete_msg")) }
    }
}

// MARK: - Selection Summary (generic)

/// Reusable multi-selection summary panel.
/// - `softActionLabel`/`softAction`: optional "soft" action (archive, terminate). Pass nil to omit.
/// - `deleteActionLabel`/`deleteAction`: destructive hard-delete button (always shown when items non-empty).
struct SelectionSummaryView<T: Identifiable>: View {
    let title: String                    // e.g. "3 Apartments selected"
    let items: [T]
    let nameFor: (T) -> String
    let emptyHint: String
    let softActionLabel: String?
    let softAction: (() -> Void)?
    let deleteActionLabel: String
    let deleteAction: () -> Void
    @Environment(\.loc) var loc

    var body: some View {
        VStack(spacing: 20) {
            if items.isEmpty {
                ContentUnavailableView(title, systemImage: "checkmark.circle",
                                       description: Text(emptyHint))
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(Color.accentColor)
                    Text(title).font(.title2.bold())
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(items) { item in
                                HStack {
                                    Text(nameFor(item)).font(.subheadline)
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxHeight: 260).frame(maxWidth: 440)

                    HStack(spacing: 12) {
                        if let label = softActionLabel, let action = softAction {
                            Button(action: action) {
                                Label(label, systemImage: "archivebox.fill").frame(minWidth: 160)
                            }
                            .buttonStyle(.borderedProminent).tint(.orange)
                        }
                        Button(role: .destructive, action: deleteAction) {
                            Label(deleteActionLabel, systemImage: "trash.fill").frame(minWidth: 160)
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

struct ApartmentRow: View {
    let apartment: Apartment
    @Environment(\.loc) var loc
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(apartment.displayName).font(.headline).lineLimit(1)
                Spacer()
                StatusBadge(text: apartment.status.rawValue, icon: apartment.status.icon)
            }
            HStack(spacing: 4) {
                Text(apartment.postalCode).foregroundStyle(.secondary)
                Text(apartment.city).foregroundStyle(.secondary)
            }
            .font(.caption).lineLimit(1)
            HStack(spacing: 8) {
                Label("\(apartment.rooms) \(loc.t("common.rooms"))", systemImage: "bed.double")
                if apartment.area > 0 {
                    Label(String(format: "%.0f m²", apartment.area), systemImage: "square")
                }
                Spacer()
                if apartment.isWG {
                    Text(apartment.occupancy).font(.caption.bold()).foregroundStyle(.purple)
                } else if apartment.rentPrice > 0 {
                    Text(apartment.rentPrice.formatted(.currency(code: "EUR")))
                        .font(.caption.bold()).foregroundStyle(.green)
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail Pane

struct ApartmentDetail: View {
    let apartment: Apartment
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.loc) var loc
    @State private var expandedTenantID: PersistentIdentifier? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(apartment.company.rawValue)
                                .font(.caption.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(companyColor(apartment.company)).clipShape(Capsule())
                            if apartment.isWG {
                                Label("WG", systemImage: "person.3.fill")
                                    .font(.caption.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.purple).clipShape(Capsule())
                            }
                            Text(apartment.displayName).font(.largeTitle.bold())
                        }
                        // Address breakdown
                        VStack(alignment: .leading, spacing: 2) {
                            Label(apartment.street, systemImage: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                            if !apartment.gate.isEmpty || !apartment.apartmentNumber.isEmpty {
                                HStack(spacing: 12) {
                                    if !apartment.gate.isEmpty {
                                        Label("\(loc.t("export.h.gate")) \(apartment.gate)", systemImage: "staircase")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if !apartment.apartmentNumber.isEmpty {
                                        Label("\(loc.t("export.h.top")) \(apartment.apartmentNumber)", systemImage: "door.left.hand.open")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Label("\(apartment.postalCode) \(apartment.city), \(apartment.country)",
                                  systemImage: "building.2")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if apartment.isWG {
                            Label(apartment.occupancy, systemImage: "person.2.fill")
                                .font(.subheadline).foregroundStyle(.purple)
                        }
                    }
                    Spacer()
                    StatusBadge(text: apartment.status.rawValue, icon: apartment.status.icon, large: true)
                }

                // Metrics
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                    if apartment.isWG {
                        MetricCard(label: loc.t("apt.max_tenants"), value: "\(apartment.maxTenants)", icon: "person.3.fill", color: .purple)
                        MetricCard(label: loc.t("apt.active_tenants"), value: "\(apartment.activeTenants.count)", icon: "person.fill.checkmark", color: .blue)
                    } else if apartment.rentPrice > 0 {
                        MetricCard(label: loc.t("apt.monthly_rent"), value: apartment.rentPrice.formatted(.currency(code: "EUR")), icon: "eurosign.circle.fill", color: .green)
                    }
                    MetricCard(label: loc.t("apt.rooms"), value: "\(apartment.rooms)", icon: "bed.double.fill", color: .blue)
                    MetricCard(label: loc.t("apt.bathrooms"), value: "\(apartment.bathrooms)", icon: "shower.fill", color: .teal)
                    if apartment.area > 0 {
                        MetricCard(label: loc.t("apt.area"), value: String(format: "%.1f m²", apartment.area), icon: "square.fill", color: .purple)
                    }
                    MetricCard(label: loc.t("apt.floor"), value: "\(apartment.floor)", icon: "building.2.fill", color: .orange)
                    MetricCard(label: loc.t("apt.contracts_count"), value: "\(apartment.contracts.count)", icon: "doc.text.fill", color: .indigo)
                }

                // Current Tenants
                VStack(alignment: .leading, spacing: 10) {
                    Label(apartment.isWG
                          ? "\(loc.t("apt.wg_tenants")) (\(apartment.activeTenants.count) / \(apartment.maxTenants))"
                          : loc.t("apt.current_tenant"),
                          systemImage: "person.2.fill")
                        .font(.headline)

                    if apartment.activeTenants.isEmpty {
                        HStack {
                            Image(systemName: "person.slash.fill").foregroundStyle(.secondary.opacity(0.5))
                            Text(apartment.isWG ? loc.t("apt.no_tenants_wg")
                                               : loc.t("apt.no_tenants"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ForEach(apartment.activeTenants) { tenant in
                            TenantProfileCard(
                                tenant: tenant,
                                isExpanded: expandedTenantID == tenant.persistentModelID,
                                onToggle: {
                                    withAnimation(.spring(response: 0.3)) {
                                        expandedTenantID = expandedTenantID == tenant.persistentModelID
                                            ? nil : tenant.persistentModelID
                                    }
                                }
                            )
                        }
                    }
                }

                // Contracts with PDF attachments
                if !apartment.contracts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc.t("apt.all_contracts") + " (\(apartment.contracts.count))", systemImage: "doc.text.fill").font(.headline)
                        ForEach(apartment.contracts) { contract in
                            VStack(spacing: 0) {
                                ContractSummaryRow(contract: contract)
                                // Show PDF attachment inline if present
                                if let filename = contract.pdfFilename, PDFManager.exists(filename: filename) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.richtext.fill")
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                        Text(filename)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(PDFManager.fileSize(filename: filename))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Button {
                                            PDFManager.open(filename: filename)
                                        } label: {
                                            Label(loc.t("common.open"), systemImage: "eye")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        Button {
                                            PDFManager.revealInFinder(filename: filename)
                                        } label: {
                                            Image(systemName: "folder")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .help(loc.t("contract.show_finder"))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .padding(.top, -4)
                                }
                            }
                        }
                    }
                }

                // Payment History
                if !apartment.contracts.isEmpty {
                    let allPayments = apartment.contracts
                        .flatMap { $0.rentPayments }
                        .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
                    if !allPayments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(loc.t("apt.payment_history") + " (\(allPayments.count))", systemImage: "eurosign.circle.fill")
                                .font(.headline)

                            // Summary row
                            let paid = allPayments.filter { $0.status == .paid }
                            let pending = allPayments.filter { $0.status == .pending }
                            let overdue = allPayments.filter { $0.status == .overdue }
                            let partial = allPayments.filter { $0.status == .partial }
                            HStack(spacing: 12) {
                                PaymentMiniChip(count: paid.count, label: loc.t("rent.status.paid"), color: .green)
                                PaymentMiniChip(count: pending.count, label: loc.t("rent.status.pending"), color: .orange)
                                PaymentMiniChip(count: overdue.count, label: loc.t("rent.status.overdue"), color: .red)
                                if partial.count > 0 {
                                    PaymentMiniChip(count: partial.count, label: loc.t("rent.status.partial"), color: .yellow)
                                }
                                Spacer()
                                let totalPaid = paid.reduce(0.0) { $0 + $1.paidAmount }
                                    + partial.reduce(0.0) { $0 + $1.paidAmount }
                                Text(loc.t("rent.total_received") + ": " + "\(totalPaid.formatted(.currency(code: "EUR")))")
                                    .font(.caption.bold()).foregroundStyle(.green)
                            }

                            // Payment list
                            VStack(spacing: 0) {
                                ForEach(Array(allPayments.prefix(20))) { payment in
                                    HStack(spacing: 10) {
                                        Image(systemName: payment.status.icon)
                                            .foregroundStyle(paymentColor(payment.status))
                                            .frame(width: 18)
                                        Text(payment.monthName)
                                            .font(.caption.bold())
                                            .frame(width: 100, alignment: .leading)
                                        if let tenant = payment.contract?.tenant {
                                            Text(tenant.fullName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .frame(maxWidth: 120, alignment: .leading)
                                        }
                                        if let num = payment.contract?.contractNumber {
                                            Text(num)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if payment.status == .partial {
                                            Text("\(payment.paidAmount.formatted(.currency(code: "EUR"))) / \(payment.amount.formatted(.currency(code: "EUR")))")
                                                .font(.caption2).foregroundStyle(.orange)
                                        } else {
                                            Text(payment.amount.formatted(.currency(code: "EUR")))
                                                .font(.caption.bold())
                                        }
                                        StatusBadge(text: payment.status.rawValue, icon: payment.status.icon)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    if payment.id != allPayments.prefix(20).last?.id {
                                        Divider().padding(.leading, 40)
                                    }
                                }
                            }
                            .background(.background.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            if allPayments.count > 20 {
                                Text("20 / \(allPayments.count) \(loc.t("rent.payments"))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Notes
                if !apartment.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(loc.t("common.notes"), systemImage: "note.text").font(.headline)
                        Text(apartment.notes).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(24)
        }
        .toolbar {
            if canEdit {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: onEdit) { Label(loc.t("common.edit"), systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) { Label(loc.t("common.delete"), systemImage: "trash") }
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Expandable Tenant Profile Card

struct TenantProfileCard: View {
    let tenant: Tenant
    let isExpanded: Bool
    let onToggle: () -> Void
    @Environment(\.loc) var loc

    var activeContract: Contract? { tenant.contracts.first { $0.status == .active } }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 44, height: 44)
                        Text(tenant.initials).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tenant.fullName).font(.subheadline.bold())
                            if !tenant.tenantNumber.isEmpty {
                                Text(tenant.tenantNumber)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Color.indigo).clipShape(Capsule())
                            }
                        }
                        HStack(spacing: 8) {
                            if !tenant.phone.isEmpty { Label(tenant.phone, systemImage: "phone.fill") }
                            if let c = activeContract {
                                Label(c.rentAmount.formatted(.currency(code: "EUR")) + "/mo", systemImage: "eurosign.circle")
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                VStack(spacing: 0) {
                    TenantInfoRow(label: loc.t("common.email"),       value: tenant.email.isEmpty ? "—" : tenant.email,             icon: "envelope.fill")
                    TenantInfoRow(label: loc.t("common.phone"),       value: tenant.phone.isEmpty ? "—" : tenant.phone,             icon: "phone.fill")
                    TenantInfoRow(label: loc.t("common.id_passport"), value: tenant.idNumber.isEmpty ? "—" : tenant.idNumber,       icon: "creditcard.fill")
                    if let c = activeContract {
                        Divider()
                        HStack {
                            Image(systemName: "doc.text.fill").foregroundStyle(Color.accentColor).frame(width: 20)
                            Text("\(loc.t("contract.title")) \(c.contractNumber)").font(.caption.bold())
                            Spacer()
                            Text("\(DateFormatter.display.string(from: c.startDate)) – \(DateFormatter.display.string(from: c.endDate))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    if !tenant.notes.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: "note.text").foregroundStyle(.secondary).frame(width: 20)
                            Text(tenant.notes).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                }
                .background(.background.tertiary)
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.accentColor.opacity(isExpanded ? 0.4 : 0), lineWidth: 1.5))
    }
}

struct TenantInfoRow: View {
    let label: String; let value: String; let icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Text(value).font(.caption.bold()).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        Divider().padding(.leading, 14)
    }
}

// MARK: - Add / Edit Form

struct AddEditApartmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    let apartment: Apartment?

    @State private var street = ""
    @State private var gate = ""
    @State private var apartmentNumber = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var country = "Austria"
    @State private var floor = 0
    @State private var rooms = 1
    @State private var bathrooms = 1
    @State private var area = 0.0
    @State private var rentPrice = 0.0
    @State private var status: ApartmentStatus = .available
    @State private var type: ApartmentType = .standard
    @State private var company: Company = .privat
    @State private var maxTenants = 2
    @State private var notes = ""

    var isEditing: Bool { apartment != nil }
    var isValid: Bool { !street.isEmpty }

    var previewName: String {
        var parts: [String] = []
        if !street.isEmpty { parts.append(street) }
        if !gate.isEmpty   { parts.append("\(loc.t("export.h.gate")) \(gate)") }
        if !apartmentNumber.isEmpty { parts.append("\(loc.t("export.h.top")) \(apartmentNumber)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.t("apt.edit") : loc.t("apt.add")).font(.title2.bold())
                Spacer()
                Button(loc.t("common.cancel")) { dismiss() }.keyboardShortcut(.escape)
                Button(isEditing ? loc.t("common.save") : loc.t("common.add")) { save() }
                    .buttonStyle(.borderedProminent).disabled(!isValid)
            }
            .padding(20)
            Divider()

            ScrollView {
                Form {
                    Section(loc.t("company.title")) {
                        Picker(loc.t("company.title"), selection: $company) {
                            ForEach(Company.allCases, id: \.self) {
                                Label($0.rawValue, systemImage: $0.icon).tag($0)
                            }
                        }
                    }
                    Section(loc.t("apt.type")) {
                        Picker(loc.t("apt.type"), selection: $type) {
                            ForEach(ApartmentType.allCases, id: \.self) {
                                Label($0.label, systemImage: $0.icon).tag($0)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        if type == .wg {
                            Stepper("\(loc.t("apt.max_tenants")): \(maxTenants)", value: $maxTenants, in: 2...20)
                        }
                        Picker(loc.t("apt.status"), selection: $status) {
                            ForEach(ApartmentStatus.allCases, id: \.self) {
                                Label($0.rawValue, systemImage: $0.icon).tag($0)
                            }
                        }
                    }

                    Section(loc.t("apt.address")) {
                        TextField(loc.t("apt.street") + " *", text: $street)
                        HStack {
                            TextField(loc.t("apt.gate"), text: $gate)
                            TextField(loc.t("apt.apt_number"), text: $apartmentNumber)
                        }
                        HStack {
                            TextField(loc.t("apt.postal"), text: $postalCode)
                            TextField(loc.t("apt.city"), text: $city)
                        }
                        TextField(loc.t("apt.country"), text: $country)
                        if !previewName.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill").foregroundStyle(Color.accentColor).font(.caption)
                                Text(loc.t("apt.display_name") + ": ").font(.caption).foregroundStyle(.secondary)
                                Text(previewName).font(.caption.bold())
                            }
                        }
                    }

                    Section(loc.t("apt.details")) {
                        Stepper(loc.t("apt.floor") + ": \(floor)", value: $floor, in: -5...100)
                        Stepper(loc.t("apt.rooms") + ": \(rooms)", value: $rooms, in: 1...20)
                        Stepper(loc.t("apt.bathrooms") + ": \(bathrooms)", value: $bathrooms, in: 1...10)
                        HStack {
                            Text(loc.t("apt.area"))
                            Spacer()
                            TextField("0", value: $area, format: .number)
                                .frame(width: 80).multilineTextAlignment(.trailing)
                        }
                    }

                    if type == .standard {
                        Section(loc.t("apt.rent_section")) {
                            HStack {
                                Text(loc.t("apt.rent"))
                                Spacer()
                                TextField("0", value: $rentPrice, format: .number)
                                    .frame(width: 100).multilineTextAlignment(.trailing)
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
        .animation(.easeInOut(duration: 0.2), value: type)
        .onAppear {
            if let apt = apartment {
                street = apt.street; gate = apt.gate; apartmentNumber = apt.apartmentNumber
                city = apt.city; postalCode = apt.postalCode; country = apt.country
                floor = apt.floor; rooms = apt.rooms; bathrooms = apt.bathrooms
                area = apt.area; rentPrice = apt.rentPrice; status = apt.status
                type = apt.type; company = apt.company; maxTenants = apt.maxTenants; notes = apt.notes
            }
        }
    }

    private func save() {
        if let apt = apartment {
            apt.street = street; apt.gate = gate; apt.apartmentNumber = apartmentNumber
            apt.city = city; apt.postalCode = postalCode; apt.country = country
            apt.floor = floor; apt.rooms = rooms; apt.bathrooms = bathrooms
            apt.area = area; apt.rentPrice = rentPrice; apt.status = status
            apt.type = type; apt.company = company; apt.maxTenants = maxTenants; apt.notes = notes
        } else {
            let apt = Apartment(street: street, gate: gate, apartmentNumber: apartmentNumber,
                                city: city, postalCode: postalCode, country: country,
                                floor: floor, rooms: rooms, bathrooms: bathrooms,
                                area: area, rentPrice: rentPrice, status: status,
                                type: type, company: company, maxTenants: maxTenants, notes: notes)
            modelContext.insert(apt)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Shared UI Components

struct StatusBadge: View {
    let text: String; let icon: String; var large: Bool = false
    var color: Color {
        switch text {
        case "Available": return .green; case "Rented": return .blue
        case "Maintenance": return .orange; case "Reserved": return .yellow
        case "Active": return .green; case "Pending": return .orange
        case "Expired": return .gray; case "Terminated": return .red
        default: return .secondary
        }
    }
    var body: some View {
        Label(text, systemImage: icon)
            .font(large ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, large ? 12 : 8).padding(.vertical, large ? 6 : 4)
            .background(color.opacity(0.12)).clipShape(Capsule())
    }
}

struct MetricCard: View {
    let label: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct FilterChip: View {
    let label: String; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.caption.weight(.medium))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
}

struct ContractSummaryRow: View {
    let contract: Contract
    var body: some View {
        HStack {
            Image(systemName: contract.category.icon).foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(contract.contractNumber).font(.caption.bold())
                    Text("(\(contract.category.rawValue))").font(.caption2).foregroundStyle(.secondary)
                }
                Text("\(DateFormatter.display.string(from: contract.startDate)) – \(DateFormatter.display.string(from: contract.endDate))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if contract.pdfFilename != nil {
                Image(systemName: "paperclip")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            StatusBadge(text: contract.status.rawValue, icon: contract.status.icon)
        }
        .padding(10).background(.background.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PaymentMiniChip: View {
    let count: Int; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(count) \(label)").font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

func companyColor(_ company: Company) -> Color {
    switch company {
    case .elfElfImmobilien: return .blue
    case .elfElfHolding: return .teal
    case .shermanImmobilien: return .orange
    case .privat: return .indigo
    }
}

private func paymentColor(_ status: PaymentStatus) -> Color {
    switch status {
    case .paid: return .green
    case .pending: return .orange
    case .overdue: return .red
    case .partial: return .yellow
    }
}
