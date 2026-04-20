import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \AppUser.fullName) private var users: [AppUser]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.loc) var loc
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedUser: AppUser?
    @State private var showAddUser = false
    @State private var editUser: AppUser?
    @State private var deleteTarget: AppUser?
    @State private var changePasswordUser: AppUser?
    @State private var showLastAdminAlert = false

    var isAdmin: Bool { authManager.currentUser?.role == .admin }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Left – User List
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(loc.t("settings.users"), systemImage: "person.3.fill")
                        .font(.headline)
                    Text(loc.t("settings.manage_access"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()

                Divider()

                List(users, selection: $selectedUser) { user in
                    UserRow(user: user, isCurrent: user.persistentModelID == authManager.currentUser?.persistentModelID)
                        .tag(user)
                }
                .listStyle(.plain)

                if isAdmin {
                    Divider()
                    Button { showAddUser = true } label: {
                        Label(loc.t("settings.add_user"), systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .padding()
                }
            }
            .frame(width: 280)

            Divider()

            // MARK: Right – User Detail
            Group {
                if let user = selectedUser {
                    UserDetail(
                        user: user,
                        isAdmin: isAdmin,
                        isSelf: user.persistentModelID == authManager.currentUser?.persistentModelID,
                        onEdit: { editUser = user },
                        onDelete: {
                            let adminCount = users.filter { $0.role == .admin }.count
                            if user.role == .admin && adminCount <= 1 {
                                showLastAdminAlert = true
                            } else {
                                deleteTarget = user
                            }
                        },
                        onChangePassword: { changePasswordUser = user }
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(spacing: 16) {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary.opacity(0.4))
                                Text(loc.t("settings.select_user"))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)

                            // Sync status card
                            SyncStatusView()
                                .padding(.horizontal, 24)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(loc.t("settings.title"))
        .sheet(isPresented: $showAddUser) { AddEditUserView(user: nil) }
        .sheet(item: $editUser) { u in AddEditUserView(user: u) }
        .sheet(item: $changePasswordUser) { user in
            ChangePasswordView(user: user)
        }
        .confirmationDialog("\(loc.t("settings.delete_user")) \(deleteTarget?.fullName ?? "")?",
                            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button(loc.t("common.delete"), role: .destructive) {
                if let u = deleteTarget {
                    if selectedUser == u { selectedUser = nil }
                    modelContext.delete(u); try? modelContext.save(); deleteTarget = nil
                }
            }
        } message: { Text(loc.t("settings.cannot_undo")) }
        .alert(loc.t("settings.cannot_delete"), isPresented: $showLastAdminAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(loc.t("settings.last_admin"))
        }
    }
}

// MARK: - Sync Status

struct SyncStatusView: View {
    @Environment(\.loc) var loc

    var iCloudURL: URL? { PropertyManagerApp.iCloudStoreURL }
    var isActive: Bool { iCloudURL != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc.t("settings.sync"), systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            HStack(spacing: 10) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isActive ? .green : .secondary)
                Text(isActive ? loc.t("settings.sync.active") : loc.t("settings.sync.inactive"))
                    .font(.subheadline)
            }
            if let url = iCloudURL {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("settings.sync.location")).font(.caption).foregroundStyle(.secondary)
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - User Row

struct UserRow: View {
    let user: AppUser
    let isCurrent: Bool
    @Environment(\.loc) var loc

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: user.role.icon).font(.caption.bold()).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(user.fullName).font(.headline)
                    if isCurrent {
                        Text(loc.t("settings.you")).font(.caption).foregroundStyle(Color.accentColor)
                    }
                }
                Text(user.role.rawValue).font(.caption).foregroundStyle(.secondary)
                Text("@\(user.username)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - User Detail

struct UserDetail: View {
    let user: AppUser
    let isAdmin: Bool
    let isSelf: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onChangePassword: () -> Void
    @Environment(\.loc) var loc

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 64, height: 64)
                        Image(systemName: user.role.icon).font(.title2).foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(user.fullName).font(.largeTitle.bold())
                            if isSelf {
                                Text(loc.t("settings.you")).font(.caption.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        Label("@\(user.username)", systemImage: "at").foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                InfoSection(title: loc.t("settings.role_permissions"), icon: "key.fill") {
                    InfoRow(label: loc.t("settings.role"), value: user.role.rawValue)
                    InfoRow(label: loc.t("settings.can_manage"), value: permissionsText(for: user.role))
                    InfoRow(label: loc.t("settings.member_since"), value: DateFormatter.display.string(from: user.createdAt))
                }

                // Permissions breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Label(loc.t("settings.access_summary"), systemImage: "checkmark.shield.fill").font(.headline)

                    ForEach(permissionList(for: user.role), id: \.0) { name, allowed in
                        HStack {
                            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(allowed ? .green : .red)
                            Text(name).font(.caption)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                if isAdmin || isSelf {
                    HStack(spacing: 10) {
                        if isAdmin {
                            Button(action: onEdit) {
                                Label(loc.t("settings.edit_user"), systemImage: "pencil")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button(action: onChangePassword) {
                            Label(loc.t("settings.change_password"), systemImage: "lock.rotation")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        if isAdmin && !isSelf {
                            Button(role: .destructive, action: onDelete) {
                                Label(loc.t("common.delete"), systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private func permissionsText(for role: UserRole) -> String {
        switch role {
        case .admin: return loc.t("settings.perm.everything")
        case .propertyManager: return loc.t("settings.perm.apt_con_ten_pay")
        case .accountant: return loc.t("settings.perm.payments_only")
        }
    }

    private func permissionList(for role: UserRole) -> [(String, Bool)] {
        switch role {
        case .admin:
            return [(loc.t("settings.perm.manage_users"), true), (loc.t("settings.perm.manage_apartments"), true),
                    (loc.t("settings.perm.manage_contracts"), true), (loc.t("settings.perm.manage_tenants"), true), (loc.t("settings.perm.manage_payments"), true)]
        case .propertyManager:
            return [(loc.t("settings.perm.manage_users"), false), (loc.t("settings.perm.manage_apartments"), true),
                    (loc.t("settings.perm.manage_contracts"), true), (loc.t("settings.perm.manage_tenants"), true), (loc.t("settings.perm.manage_payments"), false)]
        case .accountant:
            return [(loc.t("settings.perm.manage_users"), false), (loc.t("settings.perm.manage_apartments"), false),
                    (loc.t("settings.perm.manage_contracts"), false), (loc.t("settings.perm.manage_tenants"), false), (loc.t("settings.perm.manage_payments"), true)]
        }
    }
}

// MARK: - Add/Edit User

struct AddEditUserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    let user: AppUser?
    @State private var fullName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var role: UserRole = .propertyManager

    var isEditing: Bool { user != nil }
    var isValid: Bool { !fullName.isEmpty && !username.isEmpty && (isEditing || !password.isEmpty) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.t("settings.edit_user") : loc.t("settings.add_user")).font(.title2.bold())
                Spacer()
                Button(loc.t("common.cancel")) { dismiss() }.keyboardShortcut(.escape)
                Button(isEditing ? loc.t("common.save") : loc.t("settings.add_user")) { save() }
                    .buttonStyle(.borderedProminent).disabled(!isValid)
            }
            .padding(20)
            Divider()

            Form {
                Section(loc.t("settings.identity")) {
                    TextField(loc.t("settings.full_name_req"), text: $fullName)
                    TextField(loc.t("settings.username_req"), text: $username)
                        .autocorrectionDisabled()
                }
                if !isEditing {
                    Section(loc.t("settings.password")) {
                        SecureField(loc.t("settings.password_req"), text: $password)
                    }
                }
                Section(loc.t("settings.role")) {
                    Picker(loc.t("settings.role"), selection: $role) {
                        ForEach(UserRole.allCases, id: \.self) { r in
                            Label(r.rawValue, systemImage: r.icon).tag(r)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 360)
        .onAppear {
            if let u = user { fullName = u.fullName; username = u.username; role = u.role }
        }
    }

    private func save() {
        if let u = user {
            u.fullName = fullName; u.username = username; u.role = role
        } else {
            let u = AppUser(username: username, password: password, fullName: fullName, role: role)
            modelContext.insert(u)
        }
        try? modelContext.save(); dismiss()
    }
}

// MARK: - Change Password

struct ChangePasswordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) var loc

    let user: AppUser
    @State private var current = ""
    @State private var newPass = ""
    @State private var confirm = ""
    @State private var error = ""
    @EnvironmentObject var authManager: AuthManager

    var isSelf: Bool { user.persistentModelID == authManager.currentUser?.persistentModelID }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.t("settings.change_password")).font(.title2.bold())
                Spacer()
                Button(loc.t("common.cancel")) { dismiss() }.keyboardShortcut(.escape)
                Button(loc.t("settings.update")) { update() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPass.isEmpty || newPass != confirm)
            }
            .padding(20)
            Divider()

            Form {
                if isSelf {
                    Section(loc.t("settings.current_password")) {
                        SecureField(loc.t("settings.current_password_field"), text: $current)
                    }
                }
                Section(loc.t("settings.new_password")) {
                    SecureField(loc.t("settings.new_password"), text: $newPass)
                    SecureField(loc.t("settings.confirm_new"), text: $confirm)
                    if newPass != confirm && !confirm.isEmpty {
                        Text(loc.t("settings.no_match")).font(.caption).foregroundStyle(.red)
                    }
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 380, height: 300)
    }

    private func update() {
        if isSelf && user.password != current {
            error = loc.t("settings.wrong_password"); return
        }
        user.password = newPass
        try? modelContext.save()
        dismiss()
    }
}
