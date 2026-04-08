import Foundation

// MARK: - Email Account
struct EmailAccount: Identifiable, Codable, Hashable {
    let id: String
    var email: String
    var name: String
    var provider: Provider
    var isActive: Bool
    var avatarColor: String
    var lastSync: Date?
    
    enum Provider: String, Codable {
        case google = "Google"
        case outlook = "Outlook"
        case imap = "IMAP"
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - OAuth Token
struct OAuthToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?
    let issuedAt: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(issuedAt) >= Double(expiresIn - 60)
    }
}

// MARK: - Google OAuth Configuration
struct GoogleOAuthConfig {
    // Load from environment variable or use placeholder
    static var clientId: String {
        if let envClientId = ProcessInfo.processInfo.environment["VIMMAIL_GOOGLE_CLIENT_ID"] {
            return envClientId
        }
        // Check UserDefaults (set via Settings)
        if let savedClientId = UserDefaults.standard.string(forKey: "googleClientId"), !savedClientId.isEmpty {
            return savedClientId
        }
        return "YOUR_CLIENT_ID.apps.googleusercontent.com"
    }
    
    static let redirectUri = "com.vimmail:/oauth2callback"
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let revokeEndpoint = "https://oauth2.googleapis.com/revoke"
    
    static let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.labels",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ]
    
    static var scopeString: String {
        scopes.joined(separator: " ")
    }
    
    static var isConfigured: Bool {
        !clientId.contains("YOUR_CLIENT_ID")
    }
}
