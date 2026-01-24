import Foundation
import Combine

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError(Error)
    case tokenExpired
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .tokenExpired:
            return "Session expired. Please log in again."
        case .notLoggedIn:
            return "Not logged in"
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var username: String?

    private var tokenInfo: TokenInfo?
    private let keychain = KeychainManager.shared

    // Surfline's app authorization string (base64 encoded client_id:client_secret)
    private let authorizationString = "Basic NWM1OWU3YzNmMGI2Y2IxYWQwMmJhZjY2OnNrX1FxWEpkbjZOeTVzTVJ1MjdBbWcz"

    private init() {
        loadStoredCredentials()
    }

    private func loadStoredCredentials() {
        username = keychain.loadUsername()

        do {
            tokenInfo = try keychain.loadToken()
            isLoggedIn = !(tokenInfo?.isExpired ?? true)
        } catch {
            isLoggedIn = false
        }
    }

    func login(email: String, password: String) async throws {
        let url = URL(string: "https://services.surfline.com/trusted/token?isShortLived=false")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "authorizationString": authorizationString,
            "device_id": UUID().uuidString,
            "device_type": "macOS",
            "forced": true,
            "grant_type": "password",
            "password": password,
            "username": email
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError(URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 400 {
                throw AuthError.invalidCredentials
            }

            guard httpResponse.statusCode == 200 else {
                throw AuthError.networkError(URLError(.badServerResponse))
            }

            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

            let token = TokenInfo(
                accessToken: authResponse.accessToken,
                refreshToken: authResponse.refreshToken,
                expirationDate: Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
            )

            try keychain.saveToken(token)
            keychain.saveUsername(email)

            tokenInfo = token
            username = email
            isLoggedIn = true
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }

    func logout() {
        keychain.deleteToken()
        keychain.deleteUsername()
        tokenInfo = nil
        username = nil
        isLoggedIn = false
    }

    func getValidToken() async throws -> String {
        guard var token = tokenInfo else {
            throw AuthError.notLoggedIn
        }

        if token.needsRefresh {
            token = try await refreshToken(token)
        }

        return token.accessToken
    }

    private func refreshToken(_ token: TokenInfo) async throws -> TokenInfo {
        let url = URL(string: "https://services.surfline.com/trusted/token?isShortLived=false")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "authorizationString": authorizationString,
            "grant_type": "refresh_token",
            "refresh_token": token.refreshToken
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Refresh failed, user needs to log in again
            logout()
            throw AuthError.tokenExpired
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

        let newToken = TokenInfo(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            expirationDate: Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
        )

        try keychain.saveToken(newToken)
        tokenInfo = newToken

        return newToken
    }
}
