import Foundation
import Combine
import Security
import AppKit

// MARK: - Account Manager
@MainActor
class AccountManager: ObservableObject {
    @Published var accounts: [EmailAccount] = []
    @Published var tokens: [String: OAuthToken] = [:]
    @Published var isAuthenticating = false
    @Published var authError: String?
    
    private let keychainService = "com.vimmail.accounts"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadAccounts()
    }
    
    // MARK: - Account Management
    
    func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: "accounts"),
           let accounts = try? JSONDecoder().decode([EmailAccount].self, from: data) {
            self.accounts = accounts
            
            for account in accounts {
                if let token = loadTokenFromKeychain(accountId: account.id) {
                    tokens[account.id] = token
                }
            }
        }
    }
    
    func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: "accounts")
        }
    }
    
    func addAccount(_ account: EmailAccount, token: OAuthToken) {
        accounts.append(account)
        tokens[account.id] = token
        saveTokenToKeychain(token: token, accountId: account.id)
        saveAccounts()
    }
    
    func removeAccount(_ accountId: String) {
        accounts.removeAll { $0.id == accountId }
        tokens.removeValue(forKey: accountId)
        deleteTokenFromKeychain(accountId: accountId)
        saveAccounts()
    }
    
    func updateAccount(_ account: EmailAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        }
    }
    
    // MARK: - OAuth Flow
    
    func startGoogleAuth() {
        isAuthenticating = true
        authError = nil
        
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        UserDefaults.standard.set(codeVerifier, forKey: "oauth_code_verifier")
        
        var components = URLComponents(string: GoogleOAuthConfig.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleOAuthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: GoogleOAuthConfig.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfig.scopeString),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
    
    func handleOAuthCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            authError = "Invalid OAuth callback"
            isAuthenticating = false
            return
        }
        
        guard let codeVerifier = UserDefaults.standard.string(forKey: "oauth_code_verifier") else {
            authError = "Missing code verifier"
            isAuthenticating = false
            return
        }
        
        do {
            let token = try await exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
            let userInfo = try await fetchGoogleUserInfo(accessToken: token.accessToken)
            
            let account = EmailAccount(
                id: UUID().uuidString,
                email: userInfo.email,
                name: userInfo.name ?? userInfo.email,
                provider: .google,
                isActive: true,
                avatarColor: randomNordColor(),
                lastSync: nil
            )
            
            addAccount(account, token: token)
            isAuthenticating = false
            
        } catch {
            authError = error.localizedDescription
            isAuthenticating = false
        }
        
        UserDefaults.standard.removeObject(forKey: "oauth_code_verifier")
    }
    
    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: GoogleOAuthConfig.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": GoogleOAuthConfig.clientId,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": GoogleOAuthConfig.redirectUri
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiresIn: tokenResponse.expires_in,
            tokenType: tokenResponse.token_type,
            scope: tokenResponse.scope,
            issuedAt: Date()
        )
    }
    
    func refreshToken(for accountId: String) async throws -> OAuthToken {
        guard let currentToken = tokens[accountId],
              let refreshToken = currentToken.refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        var request = URLRequest(url: URL(string: GoogleOAuthConfig.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": GoogleOAuthConfig.clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let newToken = OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token ?? refreshToken,
            expiresIn: tokenResponse.expires_in,
            tokenType: tokenResponse.token_type,
            scope: tokenResponse.scope,
            issuedAt: Date()
        )
        
        tokens[accountId] = newToken
        saveTokenToKeychain(token: newToken, accountId: accountId)
        
        return newToken
    }
    
    func getValidToken(for accountId: String) async throws -> String {
        guard var token = tokens[accountId] else {
            throw AuthError.noToken
        }
        
        if token.isExpired {
            token = try await refreshToken(for: accountId)
        }
        
        return token.accessToken
    }
    
    private func fetchGoogleUserInfo(accessToken: String) async throws -> GoogleUserInfo {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GoogleUserInfo.self, from: data)
    }
    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Keychain
    
    private func saveTokenToKeychain(token: OAuthToken, accountId: String) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: accountId,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadTokenFromKeychain(accountId: String) -> OAuthToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: accountId,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = try? JSONDecoder().decode(OAuthToken.self, from: data) else {
            return nil
        }
        
        return token
    }
    
    private func deleteTokenFromKeychain(accountId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: accountId
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func randomNordColor() -> String {
        let colors = ["#8FBCBB", "#88C0D0", "#81A1C1", "#5E81AC", "#BF616A", "#D08770", "#EBCB8B", "#A3BE8C", "#B48EAD"]
        return colors.randomElement() ?? "#88C0D0"
    }
}

// MARK: - Supporting Types

struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
    let scope: String?
}

struct GoogleUserInfo: Codable {
    let id: String
    let email: String
    let name: String?
    let picture: String?
}

enum AuthError: LocalizedError {
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noRefreshToken
    case noToken
    
    var errorDescription: String? {
        switch self {
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .noRefreshToken:
            return "No refresh token available"
        case .noToken:
            return "No token found for account"
        }
    }
}

// CommonCrypto import for SHA256
import CommonCrypto
