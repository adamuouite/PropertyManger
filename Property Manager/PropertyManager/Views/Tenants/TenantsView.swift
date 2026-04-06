import SwiftUI
import SwiftData

// MARK: - Main View

struct TenantsView: View {
    @Query(sort: \Tenant.lastName) private var tenants: [Tenant]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.loc) var loc
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedTenant: Tenant?
    @State private var showAdd = false
    @State private var editTenant: Tenant?
    @State private var deleteTarget: Tenant?
    @State private var search = ""

    var canEdit: Bool { authManager.canPerform(.manageTenants) }

    var filtered: [Tenant] {
        guard !search.isEmpty else { return tenants }
        return tenants.filter {
            $0.fullName.localizedCaseInsensitiveContains(search)
            || $0.email.localizedCaseInsensitiveContains(search)
            || $0.phone.localizedCaseInsensitiveContains(search)
            || $0.tenantNumber.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Left Pane
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(loc.t("tenant.search"), text: $search).textFieldStyle(.plain)
                }
                .padding(8)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)

                Divider()

                List(filtered, selection: $selectedTenant) { tenant in
                    TenantRow(tenant: tenant).tag(tenant)
                }
                .listStyle(.plain)
            }
            .frame(width: 280)

            Divider()

            // MARK: Right Pane
            Group {
                if let tenant = selectedTenant {
                    TenantDetail(tenant: tenant, canEdit: canEdit,
                                 onEdit: { editTenant = tenant },
                                 onDelete: { deleteTarget = tenant })
                } else {
                    ContentUnavailableView(loc.t("tenant.no_selection"), systemImage: "person.2",
                                          description: Text(loc.t("tenant.no_selection_desc")))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(loc.t("tenant.title"))
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Label(loc.t("tenant.add"), systemImage: "plus") }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddEditTenantView(tenant: nil) }
        .sheet(item: $editTenant) { t in AddEditTenantView(tenant: t) }
        .confirmationDialog("\(loc.t("common.delete")) \(deleteTarget?.fullName ?? "")?",
                            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                if let t = deleteTarget {
                    for contract in t.contracts where contract.status == .active {
                        contract.status = .terminated
                    }
                    // Clean up attached ID document
                    if let doc = t.idDocumentFilename {
                        PDFManager.deleteTenantDoc(filename: doc)
                    }
                    if selectedTenant == t { selectedTenant = nil }
                    modelContext.delete(t); try? modelContext.save(); deleteTarget = nil
                }
            }
        } message: { Text(loc.t("tenant.delete_msg")) }
    }
}

// MARK: - Row

struct TenantRow: View {
    let tenant: Tenant

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 40, height: 40)
                Text(tenant.initials).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tenant.fullName).font(.headline)
                    if !tenant.tenantNumber.isEmpty {
                        Text(tenant.tenantNumber)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.indigo).clipShape(Capsule())
                    }
                }
                Text(tenant.email).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(tenant.phone).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if tenant.idDocumentFilename != nil {
                Image(systemName: "paperclip")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if !tenant.contracts.isEmpty {
                Text("\(tenant.contracts.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct TenantDetail: View {
    let tenant: Tenant
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.loc) var loc
    @State private var docError: String? = nil
    @State private var showRemoveDocConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 72, height: 72)
                        Text(tenant.initials).font(.system(size: 28, weight: .bold)).foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(tenant.fullName).font(.largeTitle.bold())
                            if !tenant.tenantNumber.isEmpty {
                                Text(tenant.tenantNumber)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.indigo).clipShape(Capsule())
                            }
                        }
                        Label(tenant.email, systemImage: "envelope.fill")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Label(tenant.phone, systemImage: "phone.fill")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Personal info
                InfoSection(title: loc.t("tenant.personal_info"), icon: "person.text.rectangle.fill") {
                    if !tenant.tenantNumber.isEmpty {
                        InfoRow(label: loc.t("tenant.tenant_number"), value: tenant.tenantNumber)
                    }
                    InfoRow(label: loc.t("tenant.id_passport_short"), value: tenant.idNumber.isEmpty ? "—" : tenant.idNumber)
                }

                // ID Document Attachment
                VStack(alignment: .leading, spacing: 10) {
                    Label(loc.t("tenant.id_document"), systemImage: "person.crop.rectangle").font(.headline)

                    if let filename = tenant.idDocumentFilename, PDFManager.tenantDocExists(filename: filename) {
                        HStack(spacing: 12) {
                            if PDFManager.isImage(filename: filename) {
                                let url = PDFManager.tenantDocURL(for: filename)
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    default:
                                        Image(systemName: "photo.fill")
                                            .font(.largeTitle).foregroundStyle(.blue)
                                    }
                                }
                            } else {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.largeTitle).foregroundStyle(.red)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(filename)
                                    .font(.caption.bold())
                                    .lineLimit(1).truncationMode(.middle)
                                Text(PDFManager.tenantDocFileSize(filename: filename))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()

                            VStack(spacing: 6) {
                                Button {
                                    PDFManager.openTenantDoc(filename: filename)
                                } label: {
                                    Label(loc.t("common.open"), systemImage: "eye").frame(minWidth: 80)
                                }
                                .buttonStyle(.borderedProminent).tint(.blue)

                                Button {
                                    PDFManager.revealTenantDocInFinder(filename: filename)
                                } label: {
                                    Label(loc.t("contract.show_finder"), systemImage: "folder").frame(minWidth: 80)
                                }
                                .buttonStyle(.bordered)

                                if canEdit {
                                    Button(role: .destructive) {
                                        showRemoveDocConfirm = true
                                    } label: {
                                        Label(loc.t("common.remove"), systemImage: "trash").frame(minWidth: 80)
                                    }
                                    .buttonStyle(.bordered).foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.title).foregroundStyle(.secondary.opacity(0.5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc.t("tenant.no_id_doc"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(loc.t("tenant.no_id_doc_desc"))
                                    .font(.caption).foregroundStyle(.secondary.opacity(0.7))
                            }
                            Spacer()
                            if canEdit {
                                Button { attachIDDocument() } label: {
                                    Label(loc.t("tenant.attach_doc"), systemImage: "paperclip")
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

                    if let err = docError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
                .confirmationDialog(loc.t("tenant.remove_doc_confirm"), isPresented: $showRemoveDocConfirm, titleVisibility: .visible) {
                    Button(loc.t("common.remove"), role: .destructive) {
                        if let filename = tenant.idDocumentFilename {
                            PDFManager.deleteTenantDoc(filename: filename)
                            tenant.idDocumentFilename = nil
                            try? modelContext.save()
                        }
                    }
                } message: {
                    Text(loc.t("tenant.remove_doc_msg"))
                }

                // Contracts
                if !tenant.contracts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(loc.t("contract.title")) (\(tenant.contracts.count))", systemImage: "doc.text.fill").font(.headline)
                        ForEach(tenant.contracts) { c in ContractSummaryRow(contract: c) }
                    }
                }

                if !tenant.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(loc.t("common.notes"), systemImage: "note.text").font(.headline)
                        Text(tenant.notes).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
        }
        .toolbar {
            if canEdit {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { attachIDDocument() } label: {
                        Label(loc.t("tenant.attach_id"), systemImage: "paperclip")
                    }
                    .help(loc.t("tenant.attach_doc_help"))
                    Button(action: onEdit) { Label(loc.t("common.edit"), systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) { Label(loc.t("common.delete"), systemImage: "trash") }
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func attachIDDocument() {
        docError = nil
        guard let sourceURL = PDFManager.pickIDDocument() else { return }
        do {
            if let old = tenant.idDocumentFilename { PDFManager.deleteTenantDoc(filename: old) }
            let filename = try PDFManager.attachIDDocument(from: sourceURL, tenantName: tenant.fullName)
            tenant.idDocumentFilename = filename
            try? modelContext.save()
        } catch {
            docError = "\(loc.t("tenant.attach_failed")) \(error.localizedDescription)"
        }
    }
}

// MARK: - Add/Edit Form

struct AddEditTenantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    let tenant: Tenant?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var idNumber = ""
    @State private var tenantNumber = ""
    @State private var notes = ""

    var isEditing: Bool { tenant != nil }
    var isValid: Bool { !firstName.isEmpty && !lastName.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.t("tenant.edit") : loc.t("tenant.add"))
                    .font(.title2.bold())
                Spacer()
                Button(loc.t("common.cancel")) { dismiss() }.keyboardShortcut(.escape)
                Button(isEditing ? loc.t("common.save") : loc.t("tenant.register")) { save() }
                    .buttonStyle(.borderedProminent).disabled(!isValid)
            }
            .padding(20)
            Divider()

            ScrollView {
                Form {
                    Section(loc.t("tenant.personal_info")) {
                        HStack {
                            TextField(loc.t("tenant.first_name") + " *", text: $firstName)
                            TextField(loc.t("tenant.last_name") + " *", text: $lastName)
                        }
                        TextField(loc.t("tenant.email"), text: $email)
                        TextField(loc.t("tenant.phone"), text: $phone)
                        TextField(loc.t("tenant.id_passport"), text: $idNumber)
                    }

                    Section(loc.t("tenant.rent_ref")) {
                        TextField(loc.t("tenant.tenant_number_field"), text: $tenantNumber)
                        Text(loc.t("tenant.tenant_number_help"))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section(loc.t("common.notes")) {
                        TextEditor(text: $notes).frame(minHeight: 60)
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(width: 520, height: 480)
        .onAppear {
            if let t = tenant {
                firstName = t.firstName; lastName = t.lastName; email = t.email
                phone = t.phone; idNumber = t.idNumber; tenantNumber = t.tenantNumber
                notes = t.notes
            }
        }
    }

    private func save() {
        if let t = tenant {
            t.firstName = firstName; t.lastName = lastName; t.email = email
            t.phone = phone; t.idNumber = idNumber; t.tenantNumber = tenantNumber; t.notes = notes
        } else {
            let t = Tenant(firstName: firstName, lastName: lastName, email: email,
                           phone: phone, idNumber: idNumber, tenantNumber: tenantNumber, notes: notes)
            modelContext.insert(t)
        }
        try? modelContext.save(); dismiss()
    }
}
