import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Thin header bar
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to Surfline")
                        .font(.headline)
                    Text("Click \"Log In\" in the navigation bar below")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
                    .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            SurflineWebLoginView(authManager: authManager) {
                dismiss()
            }
        }
        .frame(width: 480, height: 620)
    }
}

#Preview {
    LoginView(authManager: AuthManager.shared)
}
