import Foundation

// MARK: - Email Model
struct Email: Identifiable, Codable, Hashable {
    let id: String
    let threadId: String
    let accountId: String
    let messageId: String
    
    var from: EmailAddress
    var to: [EmailAddress]
    var cc: [EmailAddress]
    var bcc: [EmailAddress]
    var replyTo: [EmailAddress]
    
    var subject: String
    var snippet: String
    var bodyPlain: String?
    var bodyHtml: String?
    
    var date: Date
    var receivedDate: Date
    
    var isRead: Bool
    var isStarred: Bool
    var isSpam: Bool
    var isTrash: Bool
    var isDraft: Bool
    var isSent: Bool
    
    var labels: [String]
    var attachments: [Attachment]
    
    var inReplyTo: String?
    var references: [String]
    
    // Security indicators
    var spfStatus: SecurityStatus?
    var dkimStatus: SecurityStatus?
    var dmarcStatus: SecurityStatus?
    var isEncrypted: Bool
    
    enum SecurityStatus: String, Codable {
        case pass, fail, neutral, none
    }
    
    var isSenderVerified: Bool {
        spfStatus == .pass && dkimStatus == .pass
    }
    
    var senderTrustLevel: SenderTrustLevel {
        if isSenderVerified {
            return .verified
        } else if spfStatus == .fail || dkimStatus == .fail {
            return .suspicious
        }
        return .unknown
    }
    
    enum SenderTrustLevel {
        case verified
        case unknown
        case suspicious
    }
    
    static func == (lhs: Email, rhs: Email) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Email Address
struct EmailAddress: Codable, Hashable, Identifiable {
    var id: String { email }
    let name: String?
    let email: String
    
    var displayName: String {
        name ?? email
    }
    
    var displayString: String {
        if let name = name, !name.isEmpty {
            return "\(name) <\(email)>"
        }
        return email
    }
    
    // Extract domain for phishing detection
    var domain: String {
        email.components(separatedBy: "@").last ?? ""
    }
}

// MARK: - Attachment
struct Attachment: Identifiable, Codable, Hashable {
    let id: String
    let filename: String
    let mimeType: String
    let size: Int64
    let contentId: String?
    var isInline: Bool
    var localPath: URL?
    
    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
    
    var isPDF: Bool {
        mimeType == "application/pdf"
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var iconName: String {
        switch mimeType {
        case let type where type.hasPrefix("image/"):
            return "photo"
        case let type where type.hasPrefix("video/"):
            return "film"
        case let type where type.hasPrefix("audio/"):
            return "music.note"
        case "application/pdf":
            return "doc.richtext"
        case let type where type.contains("spreadsheet") || type.contains("excel"):
            return "tablecells"
        case let type where type.contains("presentation") || type.contains("powerpoint"):
            return "rectangle.split.3x1"
        case let type where type.contains("document") || type.contains("word"):
            return "doc.text"
        case let type where type.contains("zip") || type.contains("archive"):
            return "archivebox"
        default:
            return "doc"
        }
    }
}

// MARK: - Email Thread
struct EmailThread: Identifiable, Hashable {
    let id: String
    let accountId: String
    var emails: [Email]
    
    var subject: String {
        emails.first?.subject ?? ""
    }
    
    var latestEmail: Email? {
        emails.max(by: { $0.date < $1.date })
    }
    
    var participants: [EmailAddress] {
        var addresses = Set<EmailAddress>()
        for email in emails {
            addresses.insert(email.from)
            addresses.formUnion(email.to)
        }
        return Array(addresses)
    }
    
    var hasUnread: Bool {
        emails.contains(where: { !$0.isRead })
    }
    
    var isStarred: Bool {
        emails.contains(where: { $0.isStarred })
    }
    
    var totalAttachments: Int {
        emails.reduce(0) { $0 + $1.attachments.count }
    }
}

// MARK: - Folder
struct EmailFolder: Identifiable, Codable, Hashable {
    let id: String
    let accountId: String
    let name: String
    let type: FolderType
    var unreadCount: Int
    var totalCount: Int
    var color: String?
    
    enum FolderType: String, Codable {
        case inbox
        case sent
        case drafts
        case spam
        case trash
        case starred
        case important
        case archive
        case custom
        case allMail
    }
    
    var systemIcon: String {
        switch type {
        case .inbox: return "tray"
        case .sent: return "paperplane"
        case .drafts: return "doc.text"
        case .spam: return "exclamationmark.shield"
        case .trash: return "trash"
        case .starred: return "star"
        case .important: return "bookmark"
        case .archive: return "archivebox"
        case .custom: return "folder"
        case .allMail: return "tray.full"
        }
    }
}

// MARK: - Draft
struct Draft: Identifiable, Codable {
    let id: String
    let accountId: String
    var to: [EmailAddress]
    var cc: [EmailAddress]
    var bcc: [EmailAddress]
    var subject: String
    var bodyHtml: String
    var bodyPlain: String
    var attachments: [Attachment]
    var inReplyTo: String?
    var threadId: String?
    var lastModified: Date
    
    init(
        id: String = UUID().uuidString,
        accountId: String,
        to: [EmailAddress] = [],
        cc: [EmailAddress] = [],
        bcc: [EmailAddress] = [],
        subject: String = "",
        bodyHtml: String = "",
        bodyPlain: String = "",
        attachments: [Attachment] = [],
        inReplyTo: String? = nil,
        threadId: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.bodyHtml = bodyHtml
        self.bodyPlain = bodyPlain
        self.attachments = attachments
        self.inReplyTo = inReplyTo
        self.threadId = threadId
        self.lastModified = Date()
    }
}

// MARK: - Filter Rule
struct FilterRule: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var isEnabled: Bool
    var conditions: [FilterCondition]
    var actions: [FilterAction]
    var matchAll: Bool // AND vs OR for conditions
    var priority: Int
    
    struct FilterCondition: Codable, Hashable {
        var field: FilterField
        var matchType: MatchType
        var value: String
        
        enum FilterField: String, Codable, CaseIterable {
            case from = "From"
            case to = "To"
            case subject = "Subject"
            case body = "Body"
            case hasAttachment = "Has Attachment"
        }
        
        enum MatchType: String, Codable, CaseIterable {
            case contains = "Contains"
            case notContains = "Does not contain"
            case equals = "Equals"
            case regex = "Matches regex"
            case startsWith = "Starts with"
            case endsWith = "Ends with"
        }
        
        func matches(email: Email) -> Bool {
            let fieldValue: String
            switch field {
            case .from:
                fieldValue = email.from.email + (email.from.name ?? "")
            case .to:
                fieldValue = email.to.map { $0.email + ($0.name ?? "") }.joined(separator: " ")
            case .subject:
                fieldValue = email.subject
            case .body:
                fieldValue = email.bodyPlain ?? email.bodyHtml ?? ""
            case .hasAttachment:
                return !email.attachments.isEmpty == (value.lowercased() == "true")
            }
            
            switch matchType {
            case .contains:
                return fieldValue.localizedCaseInsensitiveContains(value)
            case .notContains:
                return !fieldValue.localizedCaseInsensitiveContains(value)
            case .equals:
                return fieldValue.localizedCaseInsensitiveCompare(value) == .orderedSame
            case .regex:
                do {
                    let regex = try NSRegularExpression(pattern: value, options: .caseInsensitive)
                    let range = NSRange(fieldValue.startIndex..., in: fieldValue)
                    return regex.firstMatch(in: fieldValue, options: [], range: range) != nil
                } catch {
                    return false
                }
            case .startsWith:
                return fieldValue.lowercased().hasPrefix(value.lowercased())
            case .endsWith:
                return fieldValue.lowercased().hasSuffix(value.lowercased())
            }
        }
    }
    
    struct FilterAction: Codable, Hashable {
        var type: ActionType
        var value: String?
        
        enum ActionType: String, Codable, CaseIterable {
            case moveToFolder = "Move to folder"
            case addLabel = "Add label"
            case markAsRead = "Mark as read"
            case markAsStarred = "Star"
            case markAsSpam = "Mark as spam"
            case delete = "Delete"
            case archive = "Archive"
            case forward = "Forward to"
            case notify = "Send notification"
        }
    }
    
    func matches(email: Email) -> Bool {
        if matchAll {
            return conditions.allSatisfy { $0.matches(email: email) }
        } else {
            return conditions.contains { $0.matches(email: email) }
        }
    }
}

// MARK: - Search Result
struct SearchResult: Identifiable {
    let id = UUID()
    let email: Email
    let matchType: MatchType
    let matchedText: String
    let highlightRange: Range<String.Index>?
    
    enum MatchType {
        case subject
        case body
        case from
        case to
        case attachment
    }
}
