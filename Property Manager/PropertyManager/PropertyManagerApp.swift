import SwiftUI
import SwiftData

@main
struct PropertyManagerApp: App {
    @StateObject private var authManager = AuthManager()
    @State private var loc = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environment(\.loc, loc)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .modelContainer(for: [
            AppUser.self,
            Apartment.self,
            Tenant.self,
            Contract.self,
            RentPayment.self
        ])
    }
}
