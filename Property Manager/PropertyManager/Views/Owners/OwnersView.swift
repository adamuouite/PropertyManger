import SwiftUI
import SwiftData

// MARK: - Main View

struct OwnersView: View {
    @Query(sort: \Owner.lastName) private var owners: [Owner]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.loc) var loc
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedOwner: Owner?
    @State private var showAdd = false
    @State private var editOwner: Owner?
    @State private var deleteTarget: Owner?
    @State private var search = ""
    @State private var isSelectMode = false
    @State private var multiSelection = Set<PersistentIdentifier>()
    @State private var showBulkDeleteConfirm = false

    var canEdit: Bool { authManager.canPerform(.manageTenants) }

    var filtered: [Owner] {
        owners.filter { o in
            search.isEmpty
                || o.fullName.localizedCaseInsensitiveContains(search)
                || o.email.localizedCaseInsensitiveContains(search)
                || o.phone.localizedCaseInsensitiveContains(search)
        }
    }

    var selectedOwners: [Owner] {
        owners.filter { multiSelection.contains($0.persistentModelID) }
    }

    var body: some View {
        HSplitView {
            // MARK: Left Pane
            VStack(spacing: 0) {
                if isSelectMode {
                    HStack(spacing: 6) {
                        Button {
                            multiSelection = multiSelection.count == filtered.count
                                ? [] : Set(filtered.map { $0.persistentModelID })
                        } label: {
                            Text(multiSelection.count == filtered.count
                                 ? loc.t("common.deselect_all") : loc.t("common.select_all"))
                                .font(.caption)
                        }.buttonStyle(.bordered)
                        Spacer()
                        if !multiSelection.isEmpty {
                            Button(role: .destructive) { showBulkDeleteConfirm = true } label: {
                                Label("\(loc.t("common.delete")) (\(multiSelection.count))", systemImage: "trash.fill")
                                    .font(.caption)
                            }.buttonStyle(.borderedProminent).tint(.red)
                        }
                        Button(loc.t("common.done")) { isSelectMode = false; multiSelection.removeAll() }
                            .buttonStyle(.bordered).font(.caption)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    Divider()
                }

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(loc.t("owner.search"), text: $search).textFieldStyle(.plain)
                }
                .padding(8)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)

                Divider()

                if isSelectMode {
                    List(selection: $multiSelection) {
                        ForEach(filtered) { owner in
                            HStack(spacing: 8) {
                                Image(systemName: multiSelection.contains(owner.persistentModelID)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(multiSelection.contains(owner.persistentModelID)
                                                     ? Color.accentColor : .secondary)
                                    .onTapGesture {
                                        if multiSelection.contains(owner.persistentModelID) {
                                            multiSelection.remove(owner.persistentModelID)
                                        } else {
                                            multiSelection.insert(owner.persistentModelID)
                                        }
                                    }
                                OwnerRow(owner: owner)
                            }
                        }
                    }.listStyle(.plain)
                } else {
                    List(filtered, selection: $selectedOwner) { owner in
                        OwnerRow(owner: owner).tag(owner)
                    }.listStyle(.plain)
                }
            }
            .frame(minWidth: 220, maxWidth: 360)

            // MARK: Right Pane
            Group {
                if isSelectMode {
                    SelectionSummaryView(
                        title: "\(selectedOwners.count) \(loc.t("owner.title"))",
                        items: selectedOwners,
                        nameFor: { $0.fullName },
                        emptyHint: loc.t("owner.no_selection_desc"),
                        softActionLabel: nil,
                        softAction: nil,
                        deleteActionLabel: "\(loc.t("common.delete")) (\(selectedOwners.count))",
                        deleteAction: { showBulkDeleteConfirm = true }
                    )
                } else if let owner = selectedOwner {
                    OwnerDetail(owner: owner, canEdit: canEdit,
                                onEdit: { editOwner = owner },
                                onDelete: { deleteTarget = owner })
                } else {
                    ContentUnavailableView(loc.t("owner.no_selection"), systemImage: "person.crop.house",
                                          description: Text(loc.t("owner.no_selection_desc")))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(loc.t("owner.title"))
        .toolbar {
            if canEdit {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !isSelectMode {
                        Button { isSelectMode = true } label: {
                            Label(loc.t("owner.select_mode"), systemImage: "checkmark.circle")
                        }
                        Button { showAdd = true } label: {
                            Label(loc.t("owner.add"), systemImage: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddEditOwnerView(owner: nil) }
        .sheet(item: $editOwner) { o in AddEditOwnerView(owner: o) }
        .confirmationDialog(String(format: loc.t("owner.delete_confirm"), deleteTarget?.fullName ?? ""),
                            isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                if let o = deleteTarget { hardDeleteOwner(o); deleteTarget = nil }
            }
        } message: { Text(loc.t("owner.delete_msg")) }
        .confirmationDialog(String(format: loc.t("owner.bulk_delete"), multiSelection.count),
                            isPresented: $showBulkDeleteConfirm, titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                for o in selectedOwners { hardDeleteOwner(o) }
                multiSelection.removeAll(); isSelectMode = false
            }
        } message: { Text(loc.t("owner.bulk_delete_msg")) }
    }

    private func hardDeleteOwner(_ o: Owner) {
        if selectedOwner == o { selectedOwner = nil }
        modelContext.delete(o)
        try? modelContext.save()
    }
}

// MARK: - Row

struct OwnerRow: View {
    let owner: Owner

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.teal.opacity(0.15)).frame(width: 40, height: 40)
                Text(owner.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(owner.fullName).font(.headline)
                    let count = owner.verwaltungsvertraege.count
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.teal)
                            .clipShape(Circle())
                    }
                }
                Text(owner.email).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(owner.phone).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct OwnerDetail: View {
    let owner: Owner
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.loc) var loc

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.teal.opacity(0.15)).frame(width: 72, height: 72)
                        Text(owner.initials)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.teal)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(owner.fullName).font(.largeTitle.bold())
                        if !owner.email.isEmpty {
                            Label(owner.email, systemImage: "envelope.fill")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if !owner.phone.isEmpty {
                            Label(owner.phone, systemImage: "phone.fill")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                // Personal info
                InfoSection(title: loc.t("owner.personal_info"), icon: "person.text.rectangle.fill") {
                    if !owner.email.isEmpty {
                        InfoRow(label: loc.t("common.email"), value: owner.email)
                    }
                    if !owner.phone.isEmpty {
                        InfoRow(label: loc.t("common.phone"), value: owner.phone)
                    }
                }

                // Verwaltungsverträge
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(loc.t("owner.linked_contracts")) (\(owner.verwaltungsvertraege.count))",
                          systemImage: "doc.text.fill")
                        .font(.headline)

                    if owner.verwaltungsvertraege.isEmpty {
                        Text(loc.t("owner.no_contracts"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ForEach(owner.verwaltungsvertraege) { contract in
                            OwnerContractCard(contract: contract)
                        }
                    }
                }

                if !owner.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(loc.t("common.notes"), systemImage: "note.text").font(.headline)
                        Text(owner.notes).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
        }
        .toolbar {
            if canEdit {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: onEdit) { Label(loc.t("common.edit"), systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) {
                        Label(loc.t("common.delete"), systemImage: "trash")
                    }.foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Contract Card (used in OwnerDetail)

struct OwnerContractCard: View {
    let contract: Contract
    @Environment(\.loc) var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(contract.contractNumber, systemImage: contract.category.icon)
                    .font(.headline)
                Spacer()
                StatusBadge(text: contract.status.rawValue, icon: contract.status.icon)
            }
            if let apt = contract.apartment {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.caption).foregroundStyle(.teal)
                    Text(apt.displayName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(apt.company.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.teal.opacity(0.8))
                        .clipShape(Capsule())
                }
                if !apt.fullAddress.isEmpty {
                    Text(apt.fullAddress)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(contract.rentAmount.formatted(.currency(code: "EUR")) + " " + loc.t("common.per_month"))
                    .font(.caption.bold()).foregroundStyle(.green)
                Spacer()
                Text("\(DateFormatter.display.string(from: contract.startDate)) – \(contract.endDate.map { DateFormatter.display.string(from: $0) } ?? "∞")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Add/Edit Form

struct AddEditOwnerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    let owner: Owner?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var notes = ""

    var isEditing: Bool { owner != nil }
    var isValid: Bool { !firstName.isEmpty && !lastName.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.t("owner.edit") : loc.t("owner.add"))
                    .font(.title2.bold())
                Spacer()
                Button(loc.t("common.cancel")) { dismiss() }.keyboardShortcut(.escape)
                Button(isEditing ? loc.t("common.save") : loc.t("owner.register")) { save() }
                    .buttonStyle(.borderedProminent).disabled(!isValid)
            }
            .padding(20)
            Divider()

            ScrollView {
                Form {
                    Section(loc.t("owner.personal_info")) {
                        HStack {
                            TextField(loc.t("owner.first_name") + " *", text: $firstName)
                            TextField(loc.t("owner.last_name") + " *", text: $lastName)
                        }
                        TextField(loc.t("owner.email"), text: $email)
                        TextField(loc.t("owner.phone"), text: $phone)
                    }
                    Section(loc.t("common.notes")) {
                        TextEditor(text: $notes).frame(minHeight: 60)
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(width: 480, height: 380)
        .onAppear {
            if let o = owner {
                firstName = o.firstName; lastName = o.lastName
                email = o.email; phone = o.phone; notes = o.notes
            }
        }
    }

    private func save() {
        if let o = owner {
            o.firstName = firstName; o.lastName = lastName
            o.email = email; o.phone = phone; o.notes = notes
        } else {
            let o = Owner(firstName: firstName, lastName: lastName,
                          email: email, phone: phone, notes: notes)
            modelContext.insert(o)
        }
        try? modelContext.save(); dismiss()
    }
}

