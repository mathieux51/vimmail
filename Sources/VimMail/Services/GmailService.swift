import Foundation

// MARK: - Gmail API Service
actor GmailService {
    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let accountManager: AccountManager
    
    init(accountManager: AccountManager) {
        self.accountManager = accountManager
    }
    
    // MARK: - Messages
    
    func listMessages(accountId: String, query: String? = nil, labelIds: [String]? = nil, maxResults: Int = 50, pageToken: String? = nil) async throws -> GmailMessageList {
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "maxResults", value: "\(maxResults)"))
        
        if let query = query {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        if let labelIds = labelIds {
            for labelId in labelIds {
                queryItems.append(URLQueryItem(name: "labelIds", value: labelId))
            }
        }
        
        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        
        return try await request(
            accountId: accountId,
            endpoint: "/messages",
            queryItems: queryItems
        )
    }
    
    func getMessage(accountId: String, messageId: String, format: MessageFormat = .full) async throws -> GmailMessage {
        return try await request(
            accountId: accountId,
            endpoint: "/messages/\(messageId)",
            queryItems: [URLQueryItem(name: "format", value: format.rawValue)]
        )
    }
    
    func modifyMessage(accountId: String, messageId: String, addLabels: [String] = [], removeLabels: [String] = []) async throws -> GmailMessage {
        let body = GmailModifyRequest(addLabelIds: addLabels, removeLabelIds: removeLabels)
        return try await request(
            accountId: accountId,
            endpoint: "/messages/\(messageId)/modify",
            method: "POST",
            body: body
        )
    }
    
    func trashMessage(accountId: String, messageId: String) async throws -> GmailMessage {
        return try await request(
            accountId: accountId,
            endpoint: "/messages/\(messageId)/trash",
            method: "POST"
        )
    }
    
    func untrashMessage(accountId: String, messageId: String) async throws -> GmailMessage {
        return try await request(
            accountId: accountId,
            endpoint: "/messages/\(messageId)/untrash",
            method: "POST"
        )
    }
    
    func deleteMessage(accountId: String, messageId: String) async throws {
        let _: EmptyResponse = try await request(
            accountId: accountId,
            endpoint: "/messages/\(messageId)",
            method: "DELETE"
        )
    }
    
    // MARK: - Send
    
    func sendMessage(accountId: String, raw: String) async throws -> GmailMessage {
        let body = GmailSendRequest(raw: raw)
        return try await request(
            accountId: accountId,
            endpoint: "/messages/send",
            method: "POST",
            body: body
        )
    }
    
    // MARK: - Drafts
    
    func createDraft(accountId: String, raw: String) async throws -> GmailDraft {
        let body = GmailDraftRequest(message: GmailDraftMessage(raw: raw))
        return try await request(
            accountId: accountId,
            endpoint: "/drafts",
            method: "POST",
            body: body
        )
    }
    
    func updateDraft(accountId: String, draftId: String, raw: String) async throws -> GmailDraft {
        let body = GmailDraftRequest(message: GmailDraftMessage(raw: raw))
        return try await request(
            accountId: accountId,
            endpoint: "/drafts/\(draftId)",
            method: "PUT",
            body: body
        )
    }
    
    // MARK: - Labels
    
    func listLabels(accountId: String) async throws -> GmailLabelList {
        return try await request(
            accountId: accountId,
            endpoint: "/labels"
        )
    }
    
    func getLabel(accountId: String, labelId: String) async throws -> GmailLabel {
        return try await request(
            accountId: accountId,
            endpoint: "/labels/\(labelId)"
        )
    }
    
    // MARK: - Attachments
    
    func getAttachment(accountId: String, messageId: String, attachmentId: String) async throws -> GmailAttachment {
        return try await request(
            accountId: accountId,
            endpoint: "/messages/\(messageId)/attachments/\(attachmentId)"
        )
    }
    
    // MARK: - Spam
    
    func reportSpam(accountId: String, messageId: String) async throws {
        _ = try await modifyMessage(accountId: accountId, messageId: messageId, addLabels: ["SPAM"], removeLabels: ["INBOX"])
    }
    
    // MARK: - Batch Operations
    
    func batchModify(accountId: String, messageIds: [String], addLabels: [String] = [], removeLabels: [String] = []) async throws {
        let body = GmailBatchModifyRequest(ids: messageIds, addLabelIds: addLabels, removeLabelIds: removeLabels)
        let _: EmptyResponse = try await request(
            accountId: accountId,
            endpoint: "/messages/batchModify",
            method: "POST",
            body: body
        )
    }
    
    // MARK: - Watch (Push Notifications)
    
    func watch(accountId: String, topicName: String, labelIds: [String] = ["INBOX"]) async throws -> GmailWatchResponse {
        let body = GmailWatchRequest(topicName: topicName, labelIds: labelIds)
        return try await request(
            accountId: accountId,
            endpoint: "/watch",
            method: "POST",
            body: body
        )
    }
    
    // MARK: - History
    
    func listHistory(accountId: String, startHistoryId: String, labelId: String? = nil) async throws -> GmailHistoryList {
        var queryItems = [URLQueryItem(name: "startHistoryId", value: startHistoryId)]
        if let labelId = labelId {
            queryItems.append(URLQueryItem(name: "labelId", value: labelId))
        }
        return try await request(
            accountId: accountId,
            endpoint: "/history",
            queryItems: queryItems
        )
    }
    
    // MARK: - Request Helper
    
    private func request<T: Decodable>(
        accountId: String,
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil
    ) async throws -> T {
        let token = try await accountManager.getValidToken(for: accountId)
        
        var components = URLComponents(string: baseURL + endpoint)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw GmailError.unauthorized
        case 403:
            throw GmailError.forbidden
        case 404:
            throw GmailError.notFound
        case 429:
            throw GmailError.rateLimited
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
}

// MARK: - API Types

enum MessageFormat: String {
    case minimal
    case full
    case raw
    case metadata
}

struct GmailMessageList: Codable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Codable {
    let id: String
    let threadId: String
}

struct GmailMessage: Codable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let historyId: String?
    let internalDate: String?
    let payload: GmailMessagePayload?
    let sizeEstimate: Int?
    let raw: String?
}

struct GmailMessagePayload: Codable {
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailMessagePayload]?
}

struct GmailHeader: Codable {
    let name: String
    let value: String
}

struct GmailBody: Codable {
    let attachmentId: String?
    let size: Int?
    let data: String?
}

struct GmailLabelList: Codable {
    let labels: [GmailLabel]
}

struct GmailLabel: Codable {
    let id: String
    let name: String
    let type: String?
    let messageListVisibility: String?
    let labelListVisibility: String?
    let messagesTotal: Int?
    let messagesUnread: Int?
    let threadsTotal: Int?
    let threadsUnread: Int?
    let color: GmailLabelColor?
}

struct GmailLabelColor: Codable {
    let textColor: String?
    let backgroundColor: String?
}

struct GmailAttachment: Codable {
    let size: Int
    let data: String
}

struct GmailDraft: Codable {
    let id: String
    let message: GmailMessage?
}

struct GmailDraftRequest: Codable {
    let message: GmailDraftMessage
}

struct GmailDraftMessage: Codable {
    let raw: String
}

struct GmailModifyRequest: Codable {
    let addLabelIds: [String]
    let removeLabelIds: [String]
}

struct GmailBatchModifyRequest: Codable {
    let ids: [String]
    let addLabelIds: [String]
    let removeLabelIds: [String]
}

struct GmailSendRequest: Codable {
    let raw: String
}

struct GmailWatchRequest: Codable {
    let topicName: String
    let labelIds: [String]
}

struct GmailWatchResponse: Codable {
    let historyId: String
    let expiration: String
}

struct GmailHistoryList: Codable {
    let history: [GmailHistory]?
    let nextPageToken: String?
    let historyId: String?
}

struct GmailHistory: Codable {
    let id: String
    let messages: [GmailMessageRef]?
    let messagesAdded: [GmailHistoryMessage]?
    let messagesDeleted: [GmailHistoryMessage]?
    let labelsAdded: [GmailHistoryLabelAction]?
    let labelsRemoved: [GmailHistoryLabelAction]?
}

struct GmailHistoryMessage: Codable {
    let message: GmailMessageRef
}

struct GmailHistoryLabelAction: Codable {
    let message: GmailMessageRef
    let labelIds: [String]
}

struct EmptyResponse: Codable {}

// MARK: - Errors

enum GmailError: LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Gmail API"
        case .unauthorized:
            return "Unauthorized. Please re-authenticate."
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .apiError(let code, let message):
            return "Gmail API error (\(code)): \(message)"
        }
    }
}

// MARK: - Email Parser
extension GmailMessage {
    func toEmail(accountId: String) -> Email {
        let headers = payload?.headers ?? []
        
        func getHeader(_ name: String) -> String? {
            headers.first { $0.name.lowercased() == name.lowercased() }?.value
        }
        
        let from = parseEmailAddress(getHeader("From") ?? "")
        let to = parseEmailAddresses(getHeader("To") ?? "")
        let cc = parseEmailAddresses(getHeader("Cc") ?? "")
        let bcc = parseEmailAddresses(getHeader("Bcc") ?? "")
        let replyTo = parseEmailAddresses(getHeader("Reply-To") ?? "")
        
        let subject = getHeader("Subject") ?? "(No Subject)"
        let messageId = getHeader("Message-ID") ?? id
        let inReplyTo = getHeader("In-Reply-To")
        let references = getHeader("References")?.components(separatedBy: .whitespaces) ?? []
        
        let dateString = getHeader("Date") ?? ""
        let date = parseDate(dateString) ?? Date(timeIntervalSince1970: Double(internalDate ?? "0") ?? 0 / 1000)
        
        let (bodyPlain, bodyHtml, attachments) = extractBodies(payload: payload)
        
        let labels = labelIds ?? []
        let spfResult = getHeader("Authentication-Results")?.contains("spf=pass") ?? false
        let dkimResult = getHeader("Authentication-Results")?.contains("dkim=pass") ?? false
        
        return Email(
            id: id,
            threadId: threadId,
            accountId: accountId,
            messageId: messageId,
            from: from,
            to: to,
            cc: cc,
            bcc: bcc,
            replyTo: replyTo,
            subject: subject,
            snippet: snippet ?? "",
            bodyPlain: bodyPlain,
            bodyHtml: bodyHtml,
            date: date,
            receivedDate: date,
            isRead: !labels.contains("UNREAD"),
            isStarred: labels.contains("STARRED"),
            isSpam: labels.contains("SPAM"),
            isTrash: labels.contains("TRASH"),
            isDraft: labels.contains("DRAFT"),
            isSent: labels.contains("SENT"),
            labels: labels,
            attachments: attachments,
            inReplyTo: inReplyTo,
            references: references,
            spfStatus: spfResult ? .pass : .none,
            dkimStatus: dkimResult ? .pass : .none,
            dmarcStatus: nil,
            isEncrypted: false
        )
    }
    
    private func parseEmailAddress(_ string: String) -> EmailAddress {
        let pattern = #"(?:"?([^"]*)"?\s*)?<?([^<>\s]+@[^<>\s]+)>?"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) {
            let name = match.range(at: 1).location != NSNotFound
                ? String(string[Range(match.range(at: 1), in: string)!]).trimmingCharacters(in: .whitespaces)
                : nil
            let email = match.range(at: 2).location != NSNotFound
                ? String(string[Range(match.range(at: 2), in: string)!])
                : string
            return EmailAddress(name: name?.isEmpty == true ? nil : name, email: email)
        }
        return EmailAddress(name: nil, email: string)
    }
    
    private func parseEmailAddresses(_ string: String) -> [EmailAddress] {
        string.components(separatedBy: ",").map { parseEmailAddress($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    private func parseDate(_ string: String) -> Date? {
        let formatters = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss z",
            "dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        for format in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    private func extractBodies(payload: GmailMessagePayload?) -> (String?, String?, [Attachment]) {
        var plainBody: String?
        var htmlBody: String?
        var attachments: [Attachment] = []
        
        func process(part: GmailMessagePayload) {
            if let mimeType = part.mimeType {
                if mimeType == "text/plain", let data = part.body?.data {
                    plainBody = decodeBase64URL(data)
                } else if mimeType == "text/html", let data = part.body?.data {
                    htmlBody = decodeBase64URL(data)
                } else if let filename = part.filename, !filename.isEmpty {
                    let attachment = Attachment(
                        id: part.body?.attachmentId ?? UUID().uuidString,
                        filename: filename,
                        mimeType: mimeType,
                        size: Int64(part.body?.size ?? 0),
                        contentId: nil,
                        isInline: false,
                        localPath: nil
                    )
                    attachments.append(attachment)
                }
            }
            
            for subpart in part.parts ?? [] {
                process(part: subpart)
            }
        }
        
        if let payload = payload {
            process(part: payload)
        }
        
        return (plainBody, htmlBody, attachments)
    }
    
    private func decodeBase64URL(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
