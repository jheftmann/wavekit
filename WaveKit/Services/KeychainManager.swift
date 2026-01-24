import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case encodingError
    case decodingError
}

final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.wavekit.auth"

    private init() {}

    func saveToken(_ tokenInfo: TokenInfo) throws {
        let data = try JSONEncoder().encode(tokenInfo)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "surfline_token",
            kSecValueData as String: data
        ]

        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func loadToken() throws -> TokenInfo {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "surfline_token",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.decodingError
        }

        return try JSONDecoder().decode(TokenInfo.self, from: data)
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "surfline_token"
        ]

        SecItemDelete(query as CFDictionary)
    }

    // Store username for display purposes (not password)
    func saveUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: "surfline_username")
    }

    func loadUsername() -> String? {
        UserDefaults.standard.string(forKey: "surfline_username")
    }

    func deleteUsername() {
        UserDefaults.standard.removeObject(forKey: "surfline_username")
    }
}
