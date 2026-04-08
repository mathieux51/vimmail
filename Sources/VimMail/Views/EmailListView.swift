import SwiftUI
import Combine

// MARK: - Email List View Model
@MainActor
class EmailListViewModel: ObservableObject {
    @Published var emails: [Email] = []
    @Published var selectedEmailId: String?
    @Published var selectedEmailIds: Set<String> = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchQuery = ""
    @Published var currentIndex = 0
    
    private var database: EmailDatabase?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupDatabase()
        loadSampleData()
    }
    
    private func setupDatabase() {
        database = EmailDatabase()
        Task {
            try? await database?.initialize()
        }
    }
    
    private func loadSampleData() {
        // Sample data for development
        let sampleEmails = [
            Email(
                id: "1",
                threadId: "t1",
                accountId: "acc1",
                messageId: "msg1",
                from: EmailAddress(name: "John Doe", email: "john@example.com"),
                to: [EmailAddress(name: "Me", email: "me@example.com")],
                cc: [],
                bcc: [],
                replyTo: [],
                subject: "Important: Project Update",
                snippet: "Hi, I wanted to share the latest updates on our project...",
                bodyPlain: "Hi,\n\nI wanted to share the latest updates on our project.\n\nBest,\nJohn",
                bodyHtml: "<p>Hi,</p><p>I wanted to share the latest updates on our project.</p><p>Best,<br>John</p>",
                date: Date().addingTimeInterval(-3600),
                receivedDate: Date().addingTimeInterval(-3600),
                isRead: false,
                isStarred: true,
                isSpam: false,
                isTrash: false,
                isDraft: false,
                isSent: false,
                labels: ["INBOX", "UNREAD"],
                attachments: [
                    Attachment(id: "att1", filename: "report.pdf", mimeType: "application/pdf", size: 1024000, contentId: nil, isInline: false, localPath: nil)
                ],
                inReplyTo: nil,
                references: [],
                spfStatus: .pass,
                dkimStatus: .pass,
                dmarcStatus: .pass,
                isEncrypted: false
            ),
            Email(
                id: "2",
                threadId: "t2",
                accountId: "acc1",
                messageId: "msg2",
                from: EmailAddress(name: "Jane Smith", email: "jane@company.com"),
                to: [EmailAddress(name: "Me", email: "me@example.com")],
                cc: [],
                bcc: [],
                replyTo: [],
                subject: "Meeting Tomorrow",
                snippet: "Just a reminder about our meeting scheduled for tomorrow at 2pm...",
                bodyPlain: "Just a reminder about our meeting scheduled for tomorrow at 2pm.\n\nSee you there!",
                bodyHtml: nil,
                date: Date().addingTimeInterval(-7200),
                receivedDate: Date().addingTimeInterval(-7200),
                isRead: true,
                isStarred: false,
                isSpam: false,
                isTrash: false,
                isDraft: false,
                isSent: false,
                labels: ["INBOX"],
                attachments: [],
                inReplyTo: nil,
                references: [],
                spfStatus: .pass,
                dkimStatus: .pass,
                dmarcStatus: nil,
                isEncrypted: false
            ),
            Email(
                id: "3",
                threadId: "t3",
                accountId: "acc1",
                messageId: "msg3",
                from: EmailAddress(name: nil, email: "suspicious@unknown-domain.xyz"),
                to: [EmailAddress(name: "Me", email: "me@example.com")],
                cc: [],
                bcc: [],
                replyTo: [],
                subject: "URGENT: Your Account Has Been Compromised!",
                snippet: "Click here immediately to secure your account...",
                bodyPlain: "Click here immediately to secure your account. This is very urgent!",
                bodyHtml: "<p style='color:red'>CLICK HERE NOW!</p>",
                date: Date().addingTimeInterval(-14400),
                receivedDate: Date().addingTimeInterval(-14400),
                isRead: false,
                isStarred: false,
                isSpam: false,
                isTrash: false,
                isDraft: false,
                isSent: false,
                labels: ["INBOX", "UNREAD"],
                attachments: [],
                inReplyTo: nil,
                references: [],
                spfStatus: .fail,
                dkimStatus: .fail,
                dmarcStatus: nil,
                isEncrypted: false
            )
        ]
        
        emails = sampleEmails
        selectedEmailId = sampleEmails.first?.id
    }
    
    // MARK: - Actions
    
    func handleAction(_ action: KeyAction) {
        switch action {
        case .moveDown:
            moveSelection(by: 1)
        case .moveUp:
            moveSelection(by: -1)
        case .goToTop:
            currentIndex = 0
            updateSelection()
        case .goToBottom:
            currentIndex = max(0, emails.count - 1)
            updateSelection()
        case .openEmail:
            // Already selected
            break
        case .toggleStar:
            toggleStarOnSelected()
        case .deleteEmail:
            deleteSelected()
        case .archive:
            archiveSelected()
        case .markUnread:
            toggleReadOnSelected()
        case .toggleSelect:
            toggleMultiSelect()
        case .extendSelectionDown:
            extendSelection(by: 1)
        case .extendSelectionUp:
            extendSelection(by: -1)
        default:
            break
        }
    }
    
    private func moveSelection(by delta: Int) {
        let newIndex = max(0, min(emails.count - 1, currentIndex + delta))
        currentIndex = newIndex
        updateSelection()
    }
    
    private func updateSelection() {
        guard currentIndex >= 0 && currentIndex < emails.count else { return }
        selectedEmailId = emails[currentIndex].id
        selectedEmailIds = [emails[currentIndex].id]
    }
    
    private func toggleMultiSelect() {
        guard let selectedId = selectedEmailId else { return }
        if selectedEmailIds.contains(selectedId) {
            selectedEmailIds.remove(selectedId)
        } else {
            selectedEmailIds.insert(selectedId)
        }
    }
    
    private func extendSelection(by delta: Int) {
        let newIndex = max(0, min(emails.count - 1, currentIndex + delta))
        for i in min(currentIndex, newIndex)...max(currentIndex, newIndex) {
            selectedEmailIds.insert(emails[i].id)
        }
        currentIndex = newIndex
    }
    
    private func toggleStarOnSelected() {
        for id in selectedEmailIds {
            if let index = emails.firstIndex(where: { $0.id == id }) {
                emails[index].isStarred.toggle()
            }
        }
    }
    
    private func deleteSelected() {
        emails.removeAll { selectedEmailIds.contains($0.id) }
        selectedEmailIds.removeAll()
        updateSelection()
    }
    
    private func archiveSelected() {
        // Move to archive
        deleteSelected()
    }
    
    private func toggleReadOnSelected() {
        for id in selectedEmailIds {
            if let index = emails.firstIndex(where: { $0.id == id }) {
                emails[index].isRead.toggle()
            }
        }
    }
    
    var selectedEmail: Email? {
        guard let id = selectedEmailId else { return nil }
        return emails.first { $0.id == id }
    }
}

// MARK: - Email List View
struct EmailListView: View {
    @EnvironmentObject var viewModel: EmailListViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar()
            
            Divider()
                .background(NordTheme.Semantic.divider)
            
            // Email list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.emails.enumerated()), id: \.element.id) { index, email in
                            EmailRowView(
                                email: email,
                                isSelected: viewModel.selectedEmailIds.contains(email.id),
                                isFocused: viewModel.selectedEmailId == email.id
                            )
                            .id(email.id)
                            .onTapGesture {
                                viewModel.currentIndex = index
                                viewModel.selectedEmailId = email.id
                                viewModel.selectedEmailIds = [email.id]
                            }
                            
                            Divider()
                                .background(NordTheme.Semantic.divider)
                        }
                    }
                }
                .onChange(of: viewModel.selectedEmailId) { _, newValue in
                    if let id = newValue {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(NordTheme.Semantic.background)
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @EnvironmentObject var viewModel: EmailListViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(NordTheme.Semantic.textMuted)
            
            TextField("Search emails...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .foregroundColor(NordTheme.Semantic.textPrimary)
                .focused($isFocused)
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(NordTheme.Semantic.textMuted)
                }
                .buttonStyle(.plain)
            }
            
            Text("/")
                .font(.caption.monospaced())
                .foregroundColor(NordTheme.Semantic.textMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NordTheme.Semantic.backgroundTertiary)
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NordTheme.Semantic.backgroundSecondary)
    }
}

// MARK: - Email Row View
struct EmailRowView: View {
    let email: Email
    let isSelected: Bool
    let isFocused: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // Selection/Unread indicator with background
            ZStack {
                Circle()
                    .fill(unreadIndicatorBackground)
                    .frame(width: 24, height: 24)
                
                if isSelected && !isFocused {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                } else if !email.isRead {
                    Circle()
                        .fill(NordTheme.nord8)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Star with distinct background
            Button(action: {}) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(email.isStarred ? NordTheme.nord13.opacity(0.2) : Color.clear)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: email.isStarred ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(email.isStarred ? NordTheme.nord13 : NordTheme.nord3)
                }
            }
            .buttonStyle(.plain)
            
            // Sender avatar with trust indicator
            ZStack(alignment: .bottomTrailing) {
                // Avatar circle
                Circle()
                    .fill(avatarColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(email.from.displayName.prefix(1).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                // Trust badge overlay
                TrustBadge(trustLevel: email.senderTrustLevel)
                    .offset(x: 4, y: 4)
            }
            
            // Sender info
            VStack(alignment: .leading, spacing: 2) {
                Text(email.from.displayName)
                    .font(.system(size: 13, weight: email.isRead ? .regular : .semibold))
                    .foregroundColor(email.isRead ? NordTheme.nord4 : NordTheme.nord6)
                    .lineLimit(1)
                
                Text(email.from.email)
                    .font(.system(size: 11))
                    .foregroundColor(senderEmailColor)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
            
            // Subject and snippet
            VStack(alignment: .leading, spacing: 3) {
                Text(email.subject)
                    .font(.system(size: 13, weight: email.isRead ? .regular : .semibold))
                    .foregroundColor(email.isRead ? NordTheme.nord4 : NordTheme.nord6)
                    .lineLimit(1)
                
                Text(email.snippet)
                    .font(.system(size: 12))
                    .foregroundColor(NordTheme.nord3)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Attachment badge
            if !email.attachments.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 12, weight: .medium))
                    Text("\(email.attachments.count)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(NordTheme.nord15)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(NordTheme.nord15.opacity(0.15))
                .cornerRadius(12)
            }
            
            // Date with subtle background
            Text(formatDate(email.date))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(NordTheme.nord4)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(NordTheme.nord2.opacity(0.5))
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor)
    }
    
    private var unreadIndicatorBackground: Color {
        if isSelected && !isFocused {
            return NordTheme.nord10
        } else if !email.isRead {
            return NordTheme.nord8.opacity(0.2)
        }
        return NordTheme.nord2.opacity(0.3)
    }
    
    private var avatarColor: Color {
        // Generate consistent color based on email
        let colors = [NordTheme.nord10, NordTheme.nord14, NordTheme.nord15, NordTheme.nord12, NordTheme.nord7]
        let index = abs(email.from.email.hashValue) % colors.count
        return colors[index]
    }
    
    private var backgroundColor: Color {
        if isFocused {
            return NordTheme.nord2
        } else if isSelected {
            return NordTheme.nord1
        }
        return Color.clear
    }
    
    private var senderEmailColor: Color {
        switch email.senderTrustLevel {
        case .verified:
            return NordTheme.nord3
        case .unknown:
            return NordTheme.nord12
        case .suspicious:
            return NordTheme.nord11
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Trust Badge (small indicator on avatar)
struct TrustBadge: View {
    let trustLevel: Email.SenderTrustLevel
    
    var body: some View {
        ZStack {
            Circle()
                .fill(NordTheme.nord0)
                .frame(width: 16, height: 16)
            
            Circle()
                .fill(badgeColor)
                .frame(width: 12, height: 12)
            
            Image(systemName: badgeIcon)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
        }
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
        case .verified: return "checkmark"
        case .unknown: return "questionmark"
        case .suspicious: return "exclamationmark"
        }
    }
}
