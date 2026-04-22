import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case apartments = "Apartments"
    case contracts = "Contracts"
    case tenants = "Tenants"
    case owners = "Owners"
    case rents = "Rent Tracking"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .apartments: return "building.2.fill"
        case .contracts: return "doc.text.fill"
        case .tenants: return "person.2.fill"
        case .owners: return "house.fill"
        case .rents: return "eurosign.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    func localizedName(_ loc: LocalizationManager) -> String {
        switch self {
        case .dashboard:  return loc.t("nav.dashboard")
        case .apartments: return loc.t("nav.apartments")
        case .contracts:  return loc.t("nav.contracts")
        case .tenants:    return loc.t("nav.tenants")
        case .owners:     return loc.t("nav.owners")
        case .rents:      return loc.t("nav.rents")
        case .settings:   return loc.t("nav.settings")
        }
    }
}

struct MainNavigationView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.loc) var loc
    @State private var selectedSection: AppSection = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 0) {
                // Language toggle
                HStack(spacing: 6) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                loc.language = lang
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(lang.flag).font(.caption)
                                Text(lang.displayName).font(.caption2.weight(.medium))
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(loc.language == lang ? Color.accentColor : Color.clear)
                            .foregroundStyle(loc.language == lang ? .white : .secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)

                List(AppSection.allCases, selection: $selectedSection) { section in
                    Label(section.localizedName(loc), systemImage: section.icon)
                        .tag(section)
                }
                .listStyle(.sidebar)
            }
            .navigationTitle(loc.t("nav.property"))
            .safeAreaInset(edge: .bottom) {
                userFooter
            }
        } detail: {
            Group {
                switch selectedSection {
                case .dashboard: DashboardView()
                case .apartments: ApartmentsView()
                case .contracts: ContractsView()
                case .tenants: TenantsView()
                case .owners: OwnersView()
                case .rents: RentsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var userFooter: some View {
        VStack(spacing: 0) {
            Divider()
            if let user = authManager.currentUser {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: user.role.icon)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(user.fullName)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(user.role.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        authManager.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(loc.t("login.sign_out"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }
}
