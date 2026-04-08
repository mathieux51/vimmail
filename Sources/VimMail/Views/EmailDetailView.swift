import SwiftUI
import WebKit

// MARK: - Email Detail View
struct EmailDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var emailViewModel: EmailListViewModel
    
    var body: some View {
        if let email = emailViewModel.selectedEmail {
            VStack(spacing: 0) {
                // Email header
                EmailHeaderView(email: email)
                
                Divider()
                    .background(NordTheme.Semantic.divider)
                
                // Email body
                HTMLPreviewView(
                    html: email.bodyHtml ?? plainTextToHtml(email.bodyPlain ?? ""),
                    isDarkMode: appState.usesDarkPreview,
                    zoom: appState.previewZoom
                )
                
                // Attachments bar
                if !email.attachments.isEmpty {
                    AttachmentsBar(attachments: email.attachments)
                }
            }
            .background(NordTheme.Semantic.background)
        } else {
            EmptyEmailView()
        }
    }
    
    private func plainTextToHtml(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        return "<p>\(escaped)</p>"
    }
}

// MARK: - Email Header View
struct EmailHeaderView: View {
    let email: Email
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subject
            Text(email.subject)
                .font(.title2.bold())
                .foregroundColor(NordTheme.Semantic.textPrimary)
            
            // Phishing warning banner
            if email.senderTrustLevel == .suspicious {
                PhishingWarningBanner()
            }
            
            // Sender info
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                Circle()
                    .fill(NordTheme.nord10)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(email.from.displayName.prefix(2).uppercased())
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        SenderVerificationBadge(trustLevel: email.senderTrustLevel)
                        
                        Text(email.from.displayName)
                            .font(.headline)
                            .foregroundColor(NordTheme.Semantic.textPrimary)
                    }
                    
                    // ALWAYS show full email address clearly
                    HStack {
                        Text("From:")
                            .font(.caption)
                            .foregroundColor(NordTheme.Semantic.textMuted)
                        
                        Text(email.from.email)
                            .font(.caption.monospaced())
                            .foregroundColor(senderEmailColor)
                            .textSelection(.enabled)
                    }
                    
                    HStack {
                        Text("To:")
                            .font(.caption)
                            .foregroundColor(NordTheme.Semantic.textMuted)
                        
                        Text(email.to.map { $0.email }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(NordTheme.Semantic.textSecondary)
                    }
                    
                    if !email.cc.isEmpty {
                        HStack {
                            Text("Cc:")
                                .font(.caption)
                                .foregroundColor(NordTheme.Semantic.textMuted)
                            
                            Text(email.cc.map { $0.email }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(NordTheme.Semantic.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Date and actions
                VStack(alignment: .trailing, spacing: 8) {
                    Text(email.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(NordTheme.Semantic.textMuted)
                    
                    // Security status
                    SecurityIndicators(email: email)
                }
            }
            
            // Quick actions
            HStack(spacing: 16) {
                ActionButton(icon: "arrowshape.turn.up.left", label: "Reply", shortcut: "r")
                ActionButton(icon: "arrowshape.turn.up.left.2", label: "Reply All", shortcut: "R")
                ActionButton(icon: "arrowshape.turn.up.right", label: "Forward", shortcut: "f")
                
                Divider().frame(height: 20)
                
                ActionButton(icon: "archivebox", label: "Archive", shortcut: "a")
                ActionButton(icon: "trash", label: "Delete", shortcut: "dd")
                ActionButton(icon: "exclamationmark.shield", label: "Spam", shortcut: "e")
                
                Spacer()
                
                // Zoom controls
                ZoomControls()
            }
        }
        .padding()
        .background(NordTheme.Semantic.backgroundSecondary)
    }
    
    private var senderEmailColor: Color {
        switch email.senderTrustLevel {
        case .verified:
            return NordTheme.Semantic.verifiedSender
        case .unknown:
            return NordTheme.Semantic.unknownSender
        case .suspicious:
            return NordTheme.Semantic.phishingWarning
        }
    }
}

// MARK: - Phishing Warning Banner
struct PhishingWarningBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(NordTheme.nord11)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Warning: This email may be suspicious")
                    .font(.subheadline.bold())
                
                Text("The sender's email failed security verification. Be cautious with links and attachments.")
                    .font(.caption)
            }
            .foregroundColor(NordTheme.nord11)
            
            Spacer()
            
            Button("Report") {
                // Report phishing
            }
            .buttonStyle(NordButtonStyle(variant: .danger))
        }
        .padding()
        .background(NordTheme.nord11.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NordTheme.nord11.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Security Indicators
struct SecurityIndicators: View {
    let email: Email
    
    var body: some View {
        HStack(spacing: 4) {
            if email.isEncrypted {
                Image(systemName: "lock.fill")
                    .foregroundColor(NordTheme.Semantic.success)
            }
            
            if email.spfStatus == .pass && email.dkimStatus == .pass {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(NordTheme.Semantic.success)
            } else if email.spfStatus == .fail || email.dkimStatus == .fail {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(NordTheme.Semantic.error)
            }
        }
        .font(.caption)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let label: String
    let shortcut: String
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
                    .font(.caption)
                
                Text(shortcut)
                    .font(.caption.monospaced())
                    .foregroundColor(NordTheme.Semantic.textMuted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(NordTheme.Semantic.backgroundTertiary)
                    .cornerRadius(3)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(NordTheme.Semantic.textSecondary)
    }
}

// MARK: - Zoom Controls
struct ZoomControls: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { appState.zoomOut() }) {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.plain)
            
            Text("\(Int(appState.previewZoom * 100))%")
                .font(.caption.monospaced())
                .frame(width: 40)
            
            Button(action: { appState.zoomIn() }) {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.plain)
            
            Button(action: { appState.resetZoom() }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            
            Divider().frame(height: 16)
            
            Button(action: { appState.togglePreviewTheme() }) {
                Image(systemName: appState.usesDarkPreview ? "sun.max" : "moon")
            }
            .buttonStyle(.plain)
            .help("Toggle preview theme (t)")
        }
        .foregroundColor(NordTheme.Semantic.textSecondary)
    }
}

// MARK: - HTML Preview View
struct HTMLPreviewView: NSViewRepresentable {
    let html: String
    let isDarkMode: Bool
    let zoom: CGFloat
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isTextInteractionEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let styledHtml = wrapHtmlWithStyles(html)
        webView.loadHTMLString(styledHtml, baseURL: nil)
        
        // Apply zoom via CSS transform, not font size
        let zoomScript = "document.body.style.zoom = '\(zoom)';"
        webView.evaluateJavaScript(zoomScript)
    }
    
    private func wrapHtmlWithStyles(_ html: String) -> String {
        let bgColor = isDarkMode ? "#2E3440" : "#ECEFF4"
        let textColor = isDarkMode ? "#D8DEE9" : "#2E3440"
        let linkColor = isDarkMode ? "#88C0D0" : "#5E81AC"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    color: \(textColor);
                    background-color: \(bgColor);
                    padding: 20px;
                    margin: 0;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                a {
                    color: \(linkColor);
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                pre, code {
                    background-color: \(isDarkMode ? "#3B4252" : "#E5E9F0");
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 13px;
                }
                blockquote {
                    border-left: 3px solid \(isDarkMode ? "#4C566A" : "#D8DEE9");
                    margin-left: 0;
                    padding-left: 16px;
                    color: \(isDarkMode ? "#81A1C1" : "#5E81AC");
                }
                table {
                    border-collapse: collapse;
                    max-width: 100%;
                }
                td, th {
                    border: 1px solid \(isDarkMode ? "#4C566A" : "#D8DEE9");
                    padding: 8px;
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
    }
}

// MARK: - Attachments Bar
struct AttachmentsBar: View {
    let attachments: [Attachment]
    @State private var selectedAttachment: Attachment?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paperclip")
                Text("\(attachments.count) Attachment\(attachments.count > 1 ? "s" : "")")
                    .font(.caption.bold())
                
                Spacer()
                
                Text("Press 'o' to open")
                    .font(.caption)
                    .foregroundColor(NordTheme.Semantic.textMuted)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(attachments) { attachment in
                        AttachmentCard(attachment: attachment, isSelected: selectedAttachment?.id == attachment.id)
                            .onTapGesture {
                                selectedAttachment = attachment
                            }
                    }
                }
            }
        }
        .padding()
        .background(NordTheme.Semantic.backgroundSecondary)
    }
}

struct AttachmentCard: View {
    let attachment: Attachment
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: attachment.iconName)
                .font(.title2)
                .foregroundColor(NordTheme.Semantic.attachment)
            
            Text(attachment.filename)
                .font(.caption)
                .foregroundColor(NordTheme.Semantic.textPrimary)
                .lineLimit(1)
            
            Text(attachment.formattedSize)
                .font(.caption2)
                .foregroundColor(NordTheme.Semantic.textMuted)
        }
        .frame(width: 100)
        .padding()
        .background(isSelected ? NordTheme.Semantic.selection : NordTheme.Semantic.backgroundTertiary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? NordTheme.Semantic.accent : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Empty Email View
struct EmptyEmailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open")
                .font(.system(size: 64))
                .foregroundColor(NordTheme.Semantic.textMuted)
            
            Text("No email selected")
                .font(.title2)
                .foregroundColor(NordTheme.Semantic.textSecondary)
            
            Text("Select an email from the list or press 'c' to compose")
                .font(.caption)
                .foregroundColor(NordTheme.Semantic.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NordTheme.Semantic.background)
    }
}

// MARK: - Sender Verification Badge
struct SenderVerificationBadge: View {
    let trustLevel: Email.SenderTrustLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(.caption.bold())
            Text(badgeText)
                .font(.caption)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var badgeColor: Color {
        switch trustLevel {
        case .verified: return NordTheme.nord14
        case .unknown: return NordTheme.nord12
        case .suspicious: return NordTheme.nord11
        }
    }
    
    private var badgeIcon: String {
        switch trustLevel {
        case .verified: return "checkmark.shield.fill"
        case .unknown: return "questionmark.circle"
        case .suspicious: return "exclamationmark.triangle.fill"
        }
    }
    
    private var badgeText: String {
        switch trustLevel {
        case .verified: return "Verified"
        case .unknown: return "Unknown"
        case .suspicious: return "Suspicious"
        }
    }
}
