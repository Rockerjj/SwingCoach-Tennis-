import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserID: String?
    @Published var displayName: String?
    @Published var isLoading = false
    @Published var error: AuthError?

    private let keychain = KeychainHelper.shared

    enum AuthError: LocalizedError {
        case signInFailed(String)
        case tokenExpired
        case unknown

        var errorDescription: String? {
            switch self {
            case .signInFailed(let msg): return "Sign in failed: \(msg)"
            case .tokenExpired: return "Session expired. Please sign in again."
            case .unknown: return "An unknown error occurred."
            }
        }
    }

    init() {
        checkExistingSession()
    }

    private func checkExistingSession() {
        if let userID = keychain.read(key: "apple_user_id") {
            currentUserID = userID
            displayName = keychain.read(key: "display_name")
            isAuthenticated = true
        }
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                error = .signInFailed("Invalid credential type")
                return
            }

            let userID = credential.user
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            keychain.save(key: "apple_user_id", value: userID)
            if !name.isEmpty {
                keychain.save(key: "display_name", value: name)
            }

            if let identityToken = credential.identityToken,
               let tokenString = String(data: identityToken, encoding: .utf8) {
                keychain.save(key: "apple_id_token", value: tokenString)
            }

            currentUserID = userID
            displayName = name.isEmpty ? nil : name
            isAuthenticated = true

        case .failure(let err):
            if (err as? ASAuthorizationError)?.code == .canceled { return }
            error = .signInFailed(err.localizedDescription)
        }
    }

    func continueAsGuest() {
        let guestID = UUID().uuidString
        keychain.save(key: "apple_user_id", value: guestID)
        keychain.save(key: "display_name", value: "Guest")
        currentUserID = guestID
        displayName = "Guest"
        isAuthenticated = true
    }

    func signOut() {
        keychain.delete(key: "apple_user_id")
        keychain.delete(key: "display_name")
        keychain.delete(key: "apple_id_token")
        currentUserID = nil
        displayName = nil
        isAuthenticated = false
    }
}

// MARK: - Keychain Helper

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
