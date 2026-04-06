import SwiftUI
import SwiftData

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.loc) var loc
    @Query private var users: [AppUser]

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isShaking = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .controlAccentColor).opacity(0.8), Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                        LogoView(
                            foreground: .white,
                            windowColor: Color(nsColor: .controlAccentColor).opacity(0.6)
                        )
                            .frame(width: 56, height: 75)
                    }
                    Text(loc.t("login.title"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(loc.t("login.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                // Card
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc.t("login.username"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(loc.t("login.username"), text: $username)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc.t("login.password"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SecureField(loc.t("login.password"), text: $password)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(attemptLogin)
                    }

                    if !errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(errorMessage)
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .offset(x: isShaking ? 8 : 0)
                        .animation(.default, value: isShaking)
                    }

                    Button(action: attemptLogin) {
                        Text(loc.t("login.sign_in"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty)
                    .keyboardShortcut(.return)
                }
                .padding(28)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(width: 360)
                .offset(x: isShaking ? 8 : 0)

                Text(loc.t("login.default_creds"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(40)
        }
        .frame(width: 640, height: 540)
    }

    private func attemptLogin() {
        if let user = users.first(where: {
            $0.username.lowercased() == username.lowercased() && $0.password == password
        }) {
            authManager.login(user)
        } else {
            errorMessage = loc.t("login.invalid")
            withAnimation(.default.repeatCount(4, autoreverses: true)) {
                isShaking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.default) {
                    isShaking = false
                }
            }
        }
    }
}
