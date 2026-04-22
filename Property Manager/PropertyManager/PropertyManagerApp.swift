import SwiftUI
import SwiftData

@main
struct PropertyManagerApp: App {
    let container: ModelContainer
    @StateObject private var authManager = AuthManager()
    @State private var loc = LocalizationManager()

    init() {
        let storeURL = Self.iCloudStoreURL ?? Self.localStoreURL
        do {
            container = try ModelContainer(
                for: AppUser.self, Apartment.self, Tenant.self, Owner.self, Contract.self, RentPayment.self,
                configurations: ModelConfiguration(url: storeURL)
            )
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
    }

    /// ~/Library/Mobile Documents/com~apple~CloudDocs/PropertyManager/PropertyManager.sqlite
    /// Returns nil if iCloud Drive is not available on this Mac.
    static var iCloudStoreURL: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let iCloudRoot = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        guard FileManager.default.fileExists(atPath: iCloudRoot.path) else { return nil }
        let folder = iCloudRoot.appendingPathComponent("PropertyManager")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("PropertyManager.sqlite")
    }

    /// Fallback: ~/Library/Application Support/PropertyManager/PropertyManager.sqlite
    static var localStoreURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("PropertyManager")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("PropertyManager.sqlite")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environment(\.loc, loc)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .modelContainer(container)
    }
}
