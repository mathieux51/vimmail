import SwiftUI

// MARK: - Add Account View
struct AddAccountView: View {
    @EnvironmentObject var accountManager: AccountManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var step: SetupStep = .enterEmail
    @State private var detectedProvider: EmailProvider?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var imapServer = ""
    @State private var imapPort = "993"
    @State private var smtpServer = ""
    @State private var smtpPort = "587"
    @State private var useSSL = true
    
    enum SetupStep {
        case enterEmail
        case providerDetected
        case manualConfig
        case authenticating
        case success
    }
    
    enum EmailProvider: Equatable {
        case google
        case outlook
        case icloud
        case yahoo
        case custom(domain: String)
        
        var name: String {
            switch self {
            case .google: return "Google"
            case .outlook: return "Microsoft Outlook"
            case .icloud: return "iCloud"
            case .yahoo: return "Yahoo"
            case .custom(let domain): return domain
            }
        }
        
        var icon: String {
            switch self {
            case .google: return "g.circle.fill"
            case .outlook: return "envelope.fill"
            case .icloud: return "icloud.fill"
            case .yahoo: return "y.circle.fill"
            case .custom: return "server.rack"
            }
        }
        
        var color: Color {
            switch self {
            case .google: return Color(hex: "#4285F4")
            case .outlook: return Color(hex: "#0078D4")
            case .icloud: return Color(hex: "#007AFF")
            case .yahoo: return Color(hex: "#6001D2")
            case .custom: return NordTheme.nord10
            }
        }
        
        var supportsOAuth: Bool {
            switch self {
            case .google, .outlook: return true
            default: return false
            }
        }
        
        var imapSettings: (server: String, port: Int)? {
            switch self {
            case .google: return ("imap.gmail.com", 993)
            case .outlook: return ("outlook.office365.com", 993)
            case .icloud: return ("imap.mail.me.com", 993)
            case .yahoo: return ("imap.mail.yahoo.com", 993)
            case .custom: return nil
            }
        }
        
        var smtpSettings: (server: String, port: Int)? {
            switch self {
            case .google: return ("smtp.gmail.com", 587)
            case .outlook: return ("smtp.office365.com", 587)
            case .icloud: return ("smtp.mail.me.com", 587)
            case .yahoo: return ("smtp.mail.yahoo.com", 587)
            case .custom: return nil
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content based on step
            ScrollView {
                VStack(spacing: 24) {
                    switch step {
                    case .enterEmail:
                        enterEmailStep
                    case .providerDetected:
                        providerDetectedStep
                    case .manualConfig:
                        manualConfigStep
                    case .authenticating:
                        authenticatingStep
                    case .success:
                        successStep
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 480, height: 500)
        .background(NordTheme.nord0)
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(NordTheme.nord4)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Add Account")
                .font(.headline)
                .foregroundColor(NordTheme.nord6)
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear.frame(width: 24, height: 24)
        }
        .padding()
        .background(NordTheme.nord1)
    }
    
    // MARK: - Enter Email Step
    private var enterEmailStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 48))
                .foregroundColor(NordTheme.nord8)
            
            Text("Enter your email address")
                .font(.title2.bold())
                .foregroundColor(NordTheme.nord6)
            
            Text("We'll automatically detect your email provider and configure the connection.")
                .font(.subheadline)
                .foregroundColor(NordTheme.nord4)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.caption)
                    .foregroundColor(NordTheme.nord4)
                
                TextField("you@example.com", text: $email)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(12)
                    .background(NordTheme.nord1)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(NordTheme.nord3, lineWidth: 1)
                    )
                    .foregroundColor(NordTheme.nord6)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
            }
            
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(NordTheme.nord11)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(NordTheme.nord11)
                }
                .padding()
                .background(NordTheme.nord11.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Provider Detected Step
    private var providerDetectedStep: some View {
        VStack(spacing: 20) {
            if let provider = detectedProvider {
                ZStack {
                    Circle()
                        .fill(provider.color.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: provider.icon)
                        .font(.system(size: 36))
                        .foregroundColor(provider.color)
                }
                
                Text(provider.name)
                    .font(.title2.bold())
                    .foregroundColor(NordTheme.nord6)
                
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(NordTheme.nord4)
                
                if provider.supportsOAuth {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(NordTheme.nord14)
                        
                        Text("Secure sign-in available")
                            .font(.subheadline)
                            .foregroundColor(NordTheme.nord14)
                        
                        Text("You'll be redirected to \(provider.name) to sign in securely. VimMail never sees your password.")
                            .font(.caption)
                            .foregroundColor(NordTheme.nord4)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(NordTheme.nord14.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 12) {
                        Text("App-specific password required")
                            .font(.subheadline.bold())
                            .foregroundColor(NordTheme.nord12)
                        
                        if provider == .icloud {
                            Text("For iCloud, generate an app-specific password at appleid.apple.com")
                                .font(.caption)
                                .foregroundColor(NordTheme.nord4)
                                .multilineTextAlignment(.center)
                        }
                        
                        SecureField("Password or App Password", text: $password)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(NordTheme.nord1)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(NordTheme.nord3, lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(NordTheme.nord1)
                    .cornerRadius(12)
                }
                
                Button(action: { step = .manualConfig }) {
                    Text("Configure manually instead")
                        .font(.caption)
                        .foregroundColor(NordTheme.nord8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Manual Config Step
    private var manualConfigStep: some View {
        VStack(spacing: 20) {
            Text("Manual Configuration")
                .font(.title2.bold())
                .foregroundColor(NordTheme.nord6)
            
            Text(email)
                .font(.subheadline)
                .foregroundColor(NordTheme.nord4)
            
            // IMAP Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Incoming Mail (IMAP)")
                    .font(.subheadline.bold())
                    .foregroundColor(NordTheme.nord6)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server")
                            .font(.caption)
                            .foregroundColor(NordTheme.nord4)
                        TextField("imap.example.com", text: $imapServer)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(NordTheme.nord1)
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port")
                            .font(.caption)
                            .foregroundColor(NordTheme.nord4)
                        TextField("993", text: $imapPort)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(NordTheme.nord1)
                            .cornerRadius(6)
                            .frame(width: 80)
                    }
                }
            }
            .padding()
            .background(NordTheme.nord2.opacity(0.5))
            .cornerRadius(8)
            
            // SMTP Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Outgoing Mail (SMTP)")
                    .font(.subheadline.bold())
                    .foregroundColor(NordTheme.nord6)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server")
                            .font(.caption)
                            .foregroundColor(NordTheme.nord4)
                        TextField("smtp.example.com", text: $smtpServer)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(NordTheme.nord1)
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port")
                            .font(.caption)
                            .foregroundColor(NordTheme.nord4)
                        TextField("587", text: $smtpPort)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(NordTheme.nord1)
                            .cornerRadius(6)
                            .frame(width: 80)
                    }
                }
            }
            .padding()
            .background(NordTheme.nord2.opacity(0.5))
            .cornerRadius(8)
            
            // Password
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(NordTheme.nord4)
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(NordTheme.nord1)
                    .cornerRadius(6)
            }
            
            Toggle("Use SSL/TLS", isOn: $useSSL)
                .foregroundColor(NordTheme.nord4)
        }
    }
    
    // MARK: - Authenticating Step
    private var authenticatingStep: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: NordTheme.nord8))
            
            Text("Connecting...")
                .font(.title2.bold())
                .foregroundColor(NordTheme.nord6)
            
            Text("Please complete the sign-in in your browser")
                .font(.subheadline)
                .foregroundColor(NordTheme.nord4)
        }
    }
    
    // MARK: - Success Step
    private var successStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(NordTheme.nord14.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(NordTheme.nord14)
            }
            
            Text("Account Added!")
                .font(.title2.bold())
                .foregroundColor(NordTheme.nord6)
            
            Text(email)
                .font(.subheadline)
                .foregroundColor(NordTheme.nord4)
            
            Text("Your emails are now syncing")
                .font(.caption)
                .foregroundColor(NordTheme.nord3)
        }
    }
    
    // MARK: - Footer
    private var footer: some View {
        HStack {
            if step != .enterEmail && step != .authenticating && step != .success {
                Button("Back") {
                    withAnimation {
                        if step == .manualConfig {
                            step = .providerDetected
                        } else {
                            step = .enterEmail
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(NordTheme.nord4)
            }
            
            Spacer()
            
            switch step {
            case .enterEmail:
                Button(action: detectProvider) {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(NordButtonStyle(variant: .primary))
                .disabled(email.isEmpty || !email.contains("@"))
                
            case .providerDetected:
                Button(action: startAuthentication) {
                    HStack {
                        if detectedProvider?.supportsOAuth == true {
                            Text("Sign in with \(detectedProvider?.name ?? "")")
                        } else {
                            Text("Connect")
                        }
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(NordButtonStyle(variant: .primary))
                .disabled(!detectedProvider!.supportsOAuth && password.isEmpty)
                
            case .manualConfig:
                Button(action: connectManually) {
                    HStack {
                        Text("Connect")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(NordButtonStyle(variant: .primary))
                .disabled(imapServer.isEmpty || smtpServer.isEmpty || password.isEmpty)
                
            case .authenticating:
                Button("Cancel") {
                    step = .providerDetected
                }
                .buttonStyle(.plain)
                .foregroundColor(NordTheme.nord4)
                
            case .success:
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(NordButtonStyle(variant: .primary))
            }
        }
        .padding()
        .background(NordTheme.nord1)
    }
    
    // MARK: - Actions
    
    private func detectProvider() {
        errorMessage = nil
        
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""
        
        // Detect provider from domain
        if domain.contains("gmail") || domain.contains("googlemail") || domain == "google.com" {
            detectedProvider = .google
        } else if domain.contains("outlook") || domain.contains("hotmail") || domain.contains("live") || domain.contains("msn") || domain == "microsoft.com" {
            detectedProvider = .outlook
        } else if domain.contains("icloud") || domain.contains("me.com") || domain.contains("mac.com") {
            detectedProvider = .icloud
        } else if domain.contains("yahoo") || domain.contains("ymail") {
            detectedProvider = .yahoo
        } else {
            // Try to detect via MX records or use custom
            detectedProvider = .custom(domain: domain)
            
            // Pre-fill IMAP/SMTP guesses
            imapServer = "imap.\(domain)"
            smtpServer = "smtp.\(domain)"
        }
        
        // Pre-fill known server settings
        if let imap = detectedProvider?.imapSettings {
            imapServer = imap.server
            imapPort = "\(imap.port)"
        }
        if let smtp = detectedProvider?.smtpSettings {
            smtpServer = smtp.server
            smtpPort = "\(smtp.port)"
        }
        
        withAnimation {
            step = .providerDetected
        }
    }
    
    private func startAuthentication() {
        guard let provider = detectedProvider else { return }
        
        withAnimation {
            step = .authenticating
        }
        
        if provider.supportsOAuth {
            switch provider {
            case .google:
                if GoogleOAuthConfig.isConfigured {
                    accountManager.startGoogleAuth()
                } else {
                    errorMessage = "Google OAuth not configured. Go to Settings > Accounts to set up."
                    step = .providerDetected
                }
            case .outlook:
                // TODO: Implement Outlook OAuth
                errorMessage = "Outlook OAuth not yet implemented"
                step = .providerDetected
            default:
                break
            }
        } else {
            // Use IMAP/SMTP with password
            connectManually()
        }
    }
    
    private func connectManually() {
        withAnimation {
            step = .authenticating
        }
        
        // TODO: Implement IMAP connection test
        // For now, simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Create account
            let account = EmailAccount(
                id: UUID().uuidString,
                email: email,
                name: email.components(separatedBy: "@").first ?? email,
                provider: .imap,
                isActive: true,
                avatarColor: randomNordColor(),
                lastSync: nil
            )
            
            // Note: In real implementation, we'd store IMAP credentials securely
            // and verify connection before adding
            
            withAnimation {
                step = .success
            }
        }
    }
    
    private func randomNordColor() -> String {
        let colors = ["#8FBCBB", "#88C0D0", "#81A1C1", "#5E81AC", "#BF616A", "#D08770", "#EBCB8B", "#A3BE8C", "#B48EAD"]
        return colors.randomElement() ?? "#88C0D0"
    }
}

// MARK: - Preview
#Preview {
    AddAccountView()
        .environmentObject(AccountManager())
}
