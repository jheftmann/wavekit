import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Sign in to Surfline")
                    .font(.headline)

                Text("Log in for full forecast data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            // Form
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .disabled(isLoading)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .password
                    }

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .disabled(isLoading)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        login()
                    }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Sign In")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
            }

            // Note about credentials
            Text("Your credentials are stored securely in Keychain")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 300)
        .onAppear {
            // Focus email field when window appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .email
            }
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.login(email: email, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView(authManager: AuthManager.shared)
}
