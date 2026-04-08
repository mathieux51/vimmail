import Foundation
import Combine

// MARK: - Claude API Service
actor ClaudeService {
    private let baseURL = "https://api.anthropic.com/v1"
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = "claude-sonnet-4-20250514") {
        self.apiKey = apiKey
        self.model = model
    }
    
    // MARK: - Reply Suggestions
    
    func suggestReply(to email: Email, tone: ReplyTone = .professional, context: String? = nil) async throws -> String {
        let systemPrompt = """
        You are an email assistant. Generate a professional email reply based on the original email.
        Keep the response concise, clear, and appropriate for business communication.
        Match the formality level of the original email.
        Do not include subject line or email headers, just the body text.
        """
        
        var userPrompt = """
        Original email from: \(email.from.displayString)
        Subject: \(email.subject)
        
        Body:
        \(email.bodyPlain ?? email.snippet)
        
        Generate a \(tone.rawValue) reply to this email.
        """
        
        if let context = context {
            userPrompt += "\n\nAdditional context: \(context)"
        }
        
        return try await sendMessage(system: systemPrompt, user: userPrompt)
    }
    
    func suggestMultipleReplies(to email: Email, count: Int = 3) async throws -> [SuggestedReply] {
        let systemPrompt = """
        You are an email assistant. Generate multiple reply options for the given email.
        Each reply should have a different tone or approach.
        Return the replies as a JSON array with objects containing "tone" and "content" fields.
        """
        
        let userPrompt = """
        Original email from: \(email.from.displayString)
        Subject: \(email.subject)
        
        Body:
        \(email.bodyPlain ?? email.snippet)
        
        Generate \(count) different reply options with varying tones (e.g., formal, friendly, brief).
        Return as JSON array: [{"tone": "...", "content": "..."}]
        """
        
        let response = try await sendMessage(system: systemPrompt, user: userPrompt)
        
        // Parse JSON response
        if let data = response.data(using: .utf8),
           let replies = try? JSONDecoder().decode([SuggestedReply].self, from: data) {
            return replies
        }
        
        // Fallback: return single reply
        return [SuggestedReply(tone: "professional", content: response)]
    }
    
    // MARK: - Autocomplete
    
    func autocomplete(text: String, context: EmailContext) async throws -> String {
        let systemPrompt = """
        You are an email writing assistant. Complete the email text naturally.
        Match the tone and style of the existing text.
        Only return the completion, not the original text.
        Keep completions concise and natural.
        """
        
        var userPrompt = "Complete this email"
        
        if !context.to.isEmpty {
            userPrompt += " to \(context.to.map { $0.displayString }.joined(separator: ", "))"
        }
        
        if !context.subject.isEmpty {
            userPrompt += " with subject: \(context.subject)"
        }
        
        userPrompt += ":\n\n\(text)"
        
        return try await sendMessage(system: systemPrompt, user: userPrompt, maxTokens: 150)
    }
    
    func autocompleteInline(text: String, cursorPosition: Int) async throws -> String {
        let beforeCursor = String(text.prefix(cursorPosition))
        let afterCursor = String(text.suffix(text.count - cursorPosition))
        
        let systemPrompt = """
        You are an email autocomplete assistant.
        Complete the text at the cursor position naturally.
        Only return the completion text that should be inserted.
        Keep completions short (1-2 sentences max).
        """
        
        let userPrompt = """
        Complete at cursor position [CURSOR]:
        \(beforeCursor)[CURSOR]\(afterCursor)
        
        Return only the text to insert at cursor.
        """
        
        return try await sendMessage(system: systemPrompt, user: userPrompt, maxTokens: 100)
    }
    
    // MARK: - Email Summarization
    
    func summarize(email: Email) async throws -> String {
        let systemPrompt = "Summarize emails concisely in 1-2 sentences."
        
        let userPrompt = """
        From: \(email.from.displayString)
        Subject: \(email.subject)
        
        \(email.bodyPlain ?? email.snippet)
        """
        
        return try await sendMessage(system: systemPrompt, user: userPrompt, maxTokens: 100)
    }
    
    func summarizeThread(emails: [Email]) async throws -> String {
        let systemPrompt = "Summarize email threads concisely, capturing the main discussion points and any action items."
        
        var userPrompt = "Summarize this email thread:\n\n"
        
        for email in emails.sorted(by: { $0.date < $1.date }) {
            userPrompt += """
            ---
            From: \(email.from.displayString)
            Date: \(email.date.formatted())
            
            \(email.bodyPlain ?? email.snippet)
            
            """
        }
        
        return try await sendMessage(system: systemPrompt, user: userPrompt, maxTokens: 300)
    }
    
    // MARK: - Smart Compose
    
    func composeEmail(instructions: String, context: EmailContext) async throws -> String {
        let systemPrompt = """
        You are an email composing assistant.
        Write professional emails based on user instructions.
        Return only the email body text.
        """
        
        var userPrompt = "Compose an email"
        
        if !context.to.isEmpty {
            userPrompt += " to \(context.to.map { $0.displayString }.joined(separator: ", "))"
        }
        
        if !context.subject.isEmpty {
            userPrompt += " about: \(context.subject)"
        }
        
        userPrompt += "\n\nInstructions: \(instructions)"
        
        if let replyTo = context.replyingTo {
            userPrompt += "\n\nThis is in reply to:\n\(replyTo.bodyPlain ?? replyTo.snippet)"
        }
        
        return try await sendMessage(system: systemPrompt, user: userPrompt)
    }
    
    // MARK: - Phishing Detection
    
    func analyzeForPhishing(email: Email) async throws -> PhishingAnalysis {
        let systemPrompt = """
        You are a security analyst. Analyze emails for phishing indicators.
        Return a JSON object with:
        - isPhishing: boolean
        - confidence: number 0-100
        - indicators: array of strings describing suspicious elements
        - recommendation: string with advice
        """
        
        let userPrompt = """
        Analyze this email for phishing:
        
        From: \(email.from.displayString)
        Subject: \(email.subject)
        
        Body:
        \(email.bodyPlain ?? email.bodyHtml ?? email.snippet)
        
        Authentication:
        - SPF: \(email.spfStatus?.rawValue ?? "unknown")
        - DKIM: \(email.dkimStatus?.rawValue ?? "unknown")
        
        Return JSON analysis.
        """
        
        let response = try await sendMessage(system: systemPrompt, user: userPrompt, maxTokens: 500)
        
        if let data = response.data(using: .utf8),
           let analysis = try? JSONDecoder().decode(PhishingAnalysis.self, from: data) {
            return analysis
        }
        
        // Default safe analysis
        return PhishingAnalysis(
            isPhishing: false,
            confidence: 0,
            indicators: [],
            recommendation: "Unable to analyze email"
        )
    }
    
    // MARK: - API Request
    
    private func sendMessage(system: String, user: String, maxTokens: Int = 1024) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [
                ClaudeMessage(role: "user", content: user)
            ]
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return result.content.first?.text ?? ""
        case 401:
            throw ClaudeError.unauthorized
        case 429:
            throw ClaudeError.rateLimited
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    // MARK: - Streaming (for autocomplete)
    
    func streamAutocomplete(text: String, context: EmailContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: URL(string: "\(baseURL)/messages")!)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let body = ClaudeRequest(
                        model: model,
                        max_tokens: 150,
                        system: "Complete the email naturally. Only return the completion.",
                        messages: [ClaudeMessage(role: "user", content: text)],
                        stream: true
                    )
                    
                    request.httpBody = try JSONEncoder().encode(body)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: ClaudeError.invalidResponse)
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(ClaudeStreamEvent.self, from: data),
                               let delta = event.delta?.text {
                                continuation.yield(delta)
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum ReplyTone: String, CaseIterable {
    case professional = "professional"
    case friendly = "friendly"
    case brief = "brief"
    case formal = "formal"
    case casual = "casual"
}

struct SuggestedReply: Codable, Identifiable {
    var id: String { tone }
    let tone: String
    let content: String
}

struct EmailContext {
    var to: [EmailAddress] = []
    var cc: [EmailAddress] = []
    var subject: String = ""
    var replyingTo: Email?
}

struct PhishingAnalysis: Codable {
    let isPhishing: Bool
    let confidence: Int
    let indicators: [String]
    let recommendation: String
}

// MARK: - Claude API Types

struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
    var stream: Bool = false
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stop_reason: String?
}

struct ClaudeContent: Codable {
    let type: String
    let text: String?
}

struct ClaudeStreamEvent: Codable {
    let type: String
    let delta: ClaudeDelta?
}

struct ClaudeDelta: Codable {
    let type: String?
    let text: String?
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .unauthorized:
            return "Invalid API key"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .apiError(let code, let message):
            return "Claude API error (\(code)): \(message)"
        }
    }
}
