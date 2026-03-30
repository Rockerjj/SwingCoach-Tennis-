import Foundation
import AuthenticationServices
import Combine
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserID: String?
    @Published var displayName: String?
    @Published var isLoading = false
    @Published var error: AuthError?

    private let keychain = KeychainHelper.shared

    // Supabase client for auth token exchange
    private let supabaseClient: SupabaseClient = {
        SupabaseClient(
            supabaseURL: URL(string: AppConstants.Supabase.projectURL)!,
            supabaseKey: AppConstants.Supabase.anonKey
        )
    }()

    enum AuthError: LocalizedError {
        case signInFailed(String)
        case tokenExpired
        case supabaseExchangeFailed(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .signInFailed(let msg): return "Sign in failed: \(msg)"
            case .tokenExpired: return "Session expired. Please sign in again."
            case .supabaseExchangeFailed(let msg): return "Authentication failed: \(msg)"
            case .unknown: return "An unknown error occurred."
            }
        }
    }

    init() {
        checkExistingSession()
        // If a previous session failed Supabase exchange, retry on next launch
        if keychain.read(key: "needs_supabase_exchange") == "true" {
            Task { await retrySupabaseExchange() }
        }
    }

    // MARK: - Session Check

    private func checkExistingSession() {
        // Check for existing Supabase access token first
        if let accessToken = keychain.read(key: "supabase_access_token"),
           let userID = keychain.read(key: "supabase_user_id"),
           !accessToken.isEmpty {
            currentUserID = userID
            displayName = keychain.read(key: "display_name")
            isAuthenticated = true

            // Try to refresh the session in the background
            Task {
                await refreshSessionIfNeeded()
            }
            return
        }

        // Fallback: check for guest session
        if let userID = keychain.read(key: "apple_user_id"),
           keychain.read(key: "display_name") == "Guest" {
            currentUserID = userID
            displayName = "Guest"
            isAuthenticated = true
        }
    }

    // MARK: - Apple Sign In → Supabase Exchange

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                error = .signInFailed("Invalid credential type")
                return
            }

            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            if !name.isEmpty {
                keychain.save(key: "display_name", value: name)
            }

            guard let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                error = .signInFailed("No identity token received from Apple")
                return
            }

            // Store Apple token as backup
            keychain.save(key: "apple_id_token", value: tokenString)
            keychain.save(key: "apple_user_id", value: credential.user)

            // Exchange Apple token for Supabase session
            isLoading = true
            Task {
                await exchangeAppleTokenWithSupabase(idToken: tokenString, appleUserID: credential.user, name: name)
            }

        case .failure(let err):
            if (err as? ASAuthorizationError)?.code == .canceled { return }
            error = .signInFailed(err.localizedDescription)
        }
    }

    private func exchangeAppleTokenWithSupabase(idToken: String, appleUserID: String, name: String) async {
        do {
            let session = try await supabaseClient.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )

            // Store Supabase session tokens
            keychain.save(key: "supabase_access_token", value: session.accessToken)
            keychain.save(key: "supabase_refresh_token", value: session.refreshToken)
            keychain.save(key: "supabase_user_id", value: session.user.id.uuidString)

            currentUserID = session.user.id.uuidString
            displayName = name.isEmpty ? (keychain.read(key: "display_name") ?? nil) : name
            isAuthenticated = true
            isLoading = false

        } catch {
            // If Supabase exchange fails, fall back to local-only auth
            // This allows the app to work offline or when Supabase is paused
            print("Supabase token exchange failed: \(error). Falling back to local auth.")
            currentUserID = appleUserID
            displayName = name.isEmpty ? nil : name
            isAuthenticated = true
            isLoading = false

            // Store a flag so we can retry exchange later
            keychain.save(key: "needs_supabase_exchange", value: "true")
            self.error = .supabaseExchangeFailed("Signed in locally. Cloud sync will retry automatically.")
        }
    }

    // MARK: - Retry Pending Supabase Exchange
    /// Called on launch if a previous Apple Sign In couldn't exchange with Supabase.
    /// Retries once when network is available.
    private func retrySupabaseExchange() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let appleToken = keychain.read(key: "apple_id_token"),
              let appleUserID = keychain.read(key: "apple_user_id"),
              !appleToken.isEmpty else { return }

        let name = keychain.read(key: "display_name") ?? ""

        do {
            let session = try await supabaseClient.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: appleToken)
            )
            keychain.save(key: "supabase_access_token", value: session.accessToken)
            keychain.save(key: "supabase_refresh_token", value: session.refreshToken)
            keychain.save(key: "supabase_user_id", value: session.user.id.uuidString)
            keychain.delete(key: "needs_supabase_exchange")
            currentUserID = session.user.id.uuidString
        } catch {
            // Still failing — will retry next launch
            print("Deferred Supabase exchange still failing: \(error)")
        }
    }

    // MARK: - Token Refresh

    private func refreshSessionIfNeeded() async {
        guard let refreshToken = keychain.read(key: "supabase_refresh_token") else { return }

        do {
            let session = try await supabaseClient.auth.refreshSession(refreshToken: refreshToken)
            keychain.save(key: "supabase_access_token", value: session.accessToken)
            keychain.save(key: "supabase_refresh_token", value: session.refreshToken)
        } catch {
            // Token refresh failed — user may need to re-authenticate
            print("Session refresh failed: \(error)")
        }
    }

    // MARK: - Get Auth Token for API Calls

    /// Returns the best available auth token for backend API calls.
    /// Prefers Supabase JWT, falls back to Apple ID token, then dev token.
    var authToken: String {
        if let supabaseToken = keychain.read(key: "supabase_access_token"),
           !supabaseToken.isEmpty {
            return supabaseToken
        }
        if let appleToken = keychain.read(key: "apple_id_token"),
           !appleToken.isEmpty {
            return appleToken
        }
        return "dev-token"
    }

    // MARK: - Guest Mode

    func continueAsGuest() {
        let guestID = UUID().uuidString
        keychain.save(key: "apple_user_id", value: guestID)
        keychain.save(key: "display_name", value: "Guest")
        currentUserID = guestID
        displayName = "Guest"
        isAuthenticated = true
    }

    // MARK: - Sign Out

    func signOut() {
        // Clear all stored tokens
        keychain.delete(key: "apple_user_id")
        keychain.delete(key: "display_name")
        keychain.delete(key: "apple_id_token")
        keychain.delete(key: "supabase_access_token")
        keychain.delete(key: "supabase_refresh_token")
        keychain.delete(key: "supabase_user_id")
        keychain.delete(key: "needs_supabase_exchange")

        currentUserID = nil
        displayName = nil
        isAuthenticated = false

        // Sign out from Supabase
        Task {
            try? await supabaseClient.auth.signOut()
        }
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
