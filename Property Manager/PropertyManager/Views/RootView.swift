import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [AppUser]
    @Query private var contracts: [Contract]

    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if authManager.isLoggedIn {
                    MainNavigationView()
                } else {
                    LoginView()
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            seedAdminIfNeeded()
            expireOverdueContracts()
        }
    }

    private func seedAdminIfNeeded() {
        guard users.isEmpty else { return }
        let admin = AppUser(
            username: "admin",
            password: "admin123",
            fullName: "Administrator",
            role: .admin
        )
        modelContext.insert(admin)
        try? modelContext.save()
    }

    private func expireOverdueContracts() {
        var changed = false
        for contract in contracts where contract.isExpired {
            contract.status = .expired
            changed = true
        }
        if changed { try? modelContext.save() }
    }
}
