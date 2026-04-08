import Foundation
import SQLite

// MARK: - Email Database
actor EmailDatabase {
    private var db: Connection?
    private let dbPath: URL
    
    // Tables
    private let emails = Table("emails")
    private let emailsFTS = VirtualTable("emails_fts")
    private let threads = Table("threads")
    private let folders = Table("folders")
    private let attachments = Table("attachments")
    private let filterRules = Table("filter_rules")
    
    // Email columns
    private let id = Expression<String>("id")
    private let threadId = Expression<String>("thread_id")
    private let accountId = Expression<String>("account_id")
    private let messageId = Expression<String>("message_id")
    private let fromEmail = Expression<String>("from_email")
    private let fromName = Expression<String?>("from_name")
    private let toJson = Expression<String>("to_json")
    private let ccJson = Expression<String?>("cc_json")
    private let bccJson = Expression<String?>("bcc_json")
    private let subject = Expression<String>("subject")
    private let snippet = Expression<String>("snippet")
    private let bodyPlain = Expression<String?>("body_plain")
    private let bodyHtml = Expression<String?>("body_html")
    private let date = Expression<Double>("date")
    private let receivedDate = Expression<Double>("received_date")
    private let isRead = Expression<Bool>("is_read")
    private let isStarred = Expression<Bool>("is_starred")
    private let isSpam = Expression<Bool>("is_spam")
    private let isTrash = Expression<Bool>("is_trash")
    private let isDraft = Expression<Bool>("is_draft")
    private let isSent = Expression<Bool>("is_sent")
    private let labelsJson = Expression<String>("labels_json")
    private let spfStatus = Expression<String?>("spf_status")
    private let dkimStatus = Expression<String?>("dkim_status")
    private let dmarcStatus = Expression<String?>("dmarc_status")
    private let isEncrypted = Expression<Bool>("is_encrypted")
    
    // Folder columns
    private let folderName = Expression<String>("name")
    private let folderType = Expression<String>("type")
    private let unreadCount = Expression<Int>("unread_count")
    private let totalCount = Expression<Int>("total_count")
    
    // Attachment columns
    private let emailId = Expression<String>("email_id")
    private let filename = Expression<String>("filename")
    private let mimeType = Expression<String>("mime_type")
    private let size = Expression<Int64>("size")
    private let contentId = Expression<String?>("content_id")
    private let isInline = Expression<Bool>("is_inline")
    private let localPath = Expression<String?>("local_path")
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vimmailDir = appSupport.appendingPathComponent("VimMail", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: vimmailDir, withIntermediateDirectories: true)
        
        dbPath = vimmailDir.appendingPathComponent("emails.sqlite")
    }
    
    func initialize() throws {
        db = try Connection(dbPath.path)
        
        // Enable WAL mode for better concurrent performance
        try db?.execute("PRAGMA journal_mode = WAL")
        try db?.execute("PRAGMA synchronous = NORMAL")
        try db?.execute("PRAGMA cache_size = -64000") // 64MB cache
        
        try createTables()
        try createIndexes()
        try createFTSTable()
    }
    
    private func createTables() throws {
        // Emails table
        try db?.run(emails.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(threadId)
            t.column(accountId)
            t.column(messageId)
            t.column(fromEmail)
            t.column(fromName)
            t.column(toJson)
            t.column(ccJson)
            t.column(bccJson)
            t.column(subject)
            t.column(snippet)
            t.column(bodyPlain)
            t.column(bodyHtml)
            t.column(date)
            t.column(receivedDate)
            t.column(isRead, defaultValue: false)
            t.column(isStarred, defaultValue: false)
            t.column(isSpam, defaultValue: false)
            t.column(isTrash, defaultValue: false)
            t.column(isDraft, defaultValue: false)
            t.column(isSent, defaultValue: false)
            t.column(labelsJson)
            t.column(spfStatus)
            t.column(dkimStatus)
            t.column(dmarcStatus)
            t.column(isEncrypted, defaultValue: false)
        })
        
        // Folders table
        try db?.run(folders.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(accountId)
            t.column(folderName)
            t.column(folderType)
            t.column(unreadCount, defaultValue: 0)
            t.column(totalCount, defaultValue: 0)
        })
        
        // Attachments table
        try db?.run(attachments.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(emailId)
            t.column(filename)
            t.column(mimeType)
            t.column(size)
            t.column(contentId)
            t.column(isInline, defaultValue: false)
            t.column(localPath)
        })
    }
    
    private func createIndexes() throws {
        try db?.run(emails.createIndex(accountId, threadId, ifNotExists: true))
        try db?.run(emails.createIndex(accountId, date, ifNotExists: true))
        try db?.run(emails.createIndex(accountId, isRead, ifNotExists: true))
        try db?.run(emails.createIndex(fromEmail, ifNotExists: true))
        try db?.run(attachments.createIndex(emailId, ifNotExists: true))
    }
    
    private func createFTSTable() throws {
        // Create FTS5 virtual table for fast full-text search
        try db?.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS emails_fts USING fts5(
                email_id,
                subject,
                body_plain,
                from_email,
                from_name,
                to_emails,
                content='emails',
                content_rowid='rowid',
                tokenize='porter unicode61'
            )
        """)
        
        // Create triggers to keep FTS in sync
        try db?.execute("""
            CREATE TRIGGER IF NOT EXISTS emails_ai AFTER INSERT ON emails BEGIN
                INSERT INTO emails_fts(email_id, subject, body_plain, from_email, from_name, to_emails)
                VALUES (NEW.id, NEW.subject, NEW.body_plain, NEW.from_email, NEW.from_name, NEW.to_json);
            END
        """)
        
        try db?.execute("""
            CREATE TRIGGER IF NOT EXISTS emails_ad AFTER DELETE ON emails BEGIN
                INSERT INTO emails_fts(emails_fts, email_id, subject, body_plain, from_email, from_name, to_emails)
                VALUES ('delete', OLD.id, OLD.subject, OLD.body_plain, OLD.from_email, OLD.from_name, OLD.to_json);
            END
        """)
        
        try db?.execute("""
            CREATE TRIGGER IF NOT EXISTS emails_au AFTER UPDATE ON emails BEGIN
                INSERT INTO emails_fts(emails_fts, email_id, subject, body_plain, from_email, from_name, to_emails)
                VALUES ('delete', OLD.id, OLD.subject, OLD.body_plain, OLD.from_email, OLD.from_name, OLD.to_json);
                INSERT INTO emails_fts(email_id, subject, body_plain, from_email, from_name, to_emails)
                VALUES (NEW.id, NEW.subject, NEW.body_plain, NEW.from_email, NEW.from_name, NEW.to_json);
            END
        """)
    }
    
    // MARK: - CRUD Operations
    
    func insertEmail(_ email: Email) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        
        let encoder = JSONEncoder()
        let toData = try encoder.encode(email.to)
        let ccData = try encoder.encode(email.cc)
        let bccData = try encoder.encode(email.bcc)
        let labelsData = try encoder.encode(email.labels)
        
        try db.run(emails.insert(or: .replace,
            id <- email.id,
            threadId <- email.threadId,
            accountId <- email.accountId,
            messageId <- email.messageId,
            fromEmail <- email.from.email,
            fromName <- email.from.name,
            toJson <- String(data: toData, encoding: .utf8)!,
            ccJson <- String(data: ccData, encoding: .utf8),
            bccJson <- String(data: bccData, encoding: .utf8),
            subject <- email.subject,
            snippet <- email.snippet,
            bodyPlain <- email.bodyPlain,
            bodyHtml <- email.bodyHtml,
            date <- email.date.timeIntervalSince1970,
            receivedDate <- email.receivedDate.timeIntervalSince1970,
            isRead <- email.isRead,
            isStarred <- email.isStarred,
            isSpam <- email.isSpam,
            isTrash <- email.isTrash,
            isDraft <- email.isDraft,
            isSent <- email.isSent,
            labelsJson <- String(data: labelsData, encoding: .utf8)!,
            spfStatus <- email.spfStatus?.rawValue,
            dkimStatus <- email.dkimStatus?.rawValue,
            dmarcStatus <- email.dmarcStatus?.rawValue,
            isEncrypted <- email.isEncrypted
        ))
        
        // Insert attachments
        for attachment in email.attachments {
            try insertAttachment(attachment, emailId: email.id)
        }
    }
    
    func insertAttachment(_ attachment: Attachment, emailId: String) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        
        try db.run(attachments.insert(or: .replace,
            id <- attachment.id,
            self.emailId <- emailId,
            filename <- attachment.filename,
            mimeType <- attachment.mimeType,
            size <- attachment.size,
            contentId <- attachment.contentId,
            isInline <- attachment.isInline,
            localPath <- attachment.localPath?.path
        ))
    }
    
    func fetchEmails(accountId accountIdValue: String, folderId: String?, limit: Int = 50, offset: Int = 0) throws -> [Email] {
        guard let db = db else { throw DatabaseError.notInitialized }
        
        var query = emails.filter(self.accountId == accountIdValue)
            .order(date.desc)
            .limit(limit, offset: offset)
        
        if let folderId = folderId {
            query = query.filter(labelsJson.like("%\(folderId)%"))
        }
        
        var results: [Email] = []
        for row in try db.prepare(query) {
            if let email = try? parseEmailRow(row) {
                results.append(email)
            }
        }
        return results
    }
    
    func fetchEmail(id emailId: String) throws -> Email? {
        guard let db = db else { throw DatabaseError.notInitialized }
        
        let query = emails.filter(id == emailId)
        
        for row in try db.prepare(query) {
            return try parseEmailRow(row)
        }
        return nil
    }
    
    // MARK: - Fast Search with FTS5
    
    func search(query searchQuery: String, accountId accountIdValue: String, limit: Int = 100) throws -> [Email] {
        guard let db = db else { throw DatabaseError.notInitialized }
        
        // Use FTS5 for fast full-text search
        let sql = """
            SELECT e.* FROM emails e
            JOIN emails_fts fts ON e.id = fts.email_id
            WHERE emails_fts MATCH ?
            AND e.account_id = ?
            ORDER BY rank
            LIMIT ?
        """
        
        // Prepare search query for FTS5
        let ftsQuery = searchQuery
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { "\($0)*" }
            .joined(separator: " ")
        
        var results: [Email] = []
        let statement = try db.prepare(sql)
        
        for row in try statement.bind(ftsQuery, accountIdValue, limit) {
            // Parse the result
            if let emailId = row[0] as? String,
               let email = try? fetchEmail(id: emailId) {
                results.append(email)
            }
        }
        
        return results
    }
    
    // MARK: - Update Operations
    
    func markAsRead(emailId: String, read: Bool) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let email = emails.filter(id == emailId)
        try db.run(email.update(isRead <- read))
    }
    
    func markAsStarred(emailId: String, starred: Bool) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let email = emails.filter(id == emailId)
        try db.run(email.update(isStarred <- starred))
    }
    
    func markAsSpam(emailId: String, spam: Bool) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let email = emails.filter(id == emailId)
        try db.run(email.update(isSpam <- spam))
    }
    
    func moveToTrash(emailId: String) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let email = emails.filter(id == emailId)
        try db.run(email.update(isTrash <- true))
    }
    
    func deleteEmail(emailId: String) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let email = emails.filter(id == emailId)
        try db.run(email.delete())
        
        let emailAttachments = attachments.filter(self.emailId == emailId)
        try db.run(emailAttachments.delete())
    }
    
    // MARK: - Helpers
    
    private func parseEmailRow(_ row: Row) throws -> Email {
        let decoder = JSONDecoder()
        
        let toData = row[toJson].data(using: .utf8)!
        let toAddresses = try decoder.decode([EmailAddress].self, from: toData)
        
        let ccAddresses: [EmailAddress]
        if let ccData = row[ccJson]?.data(using: .utf8) {
            ccAddresses = (try? decoder.decode([EmailAddress].self, from: ccData)) ?? []
        } else {
            ccAddresses = []
        }
        
        let bccAddresses: [EmailAddress]
        if let bccData = row[bccJson]?.data(using: .utf8) {
            bccAddresses = (try? decoder.decode([EmailAddress].self, from: bccData)) ?? []
        } else {
            bccAddresses = []
        }
        
        let labelsData = row[labelsJson].data(using: .utf8)!
        let labels = try decoder.decode([String].self, from: labelsData)
        
        let emailAttachments = try fetchAttachments(for: row[id])
        
        return Email(
            id: row[id],
            threadId: row[threadId],
            accountId: row[accountId],
            messageId: row[messageId],
            from: EmailAddress(name: row[fromName], email: row[fromEmail]),
            to: toAddresses,
            cc: ccAddresses,
            bcc: bccAddresses,
            replyTo: [],
            subject: row[subject],
            snippet: row[snippet],
            bodyPlain: row[bodyPlain],
            bodyHtml: row[bodyHtml],
            date: Date(timeIntervalSince1970: row[date]),
            receivedDate: Date(timeIntervalSince1970: row[receivedDate]),
            isRead: row[isRead],
            isStarred: row[isStarred],
            isSpam: row[isSpam],
            isTrash: row[isTrash],
            isDraft: row[isDraft],
            isSent: row[isSent],
            labels: labels,
            attachments: emailAttachments,
            inReplyTo: nil,
            references: [],
            spfStatus: row[spfStatus].flatMap { Email.SecurityStatus(rawValue: $0) },
            dkimStatus: row[dkimStatus].flatMap { Email.SecurityStatus(rawValue: $0) },
            dmarcStatus: row[dmarcStatus].flatMap { Email.SecurityStatus(rawValue: $0) },
            isEncrypted: row[isEncrypted]
        )
    }
    
    private func fetchAttachments(for emailId: String) throws -> [Attachment] {
        guard let db = db else { throw DatabaseError.notInitialized }
        
        let query = attachments.filter(self.emailId == emailId)
        var results: [Attachment] = []
        
        for row in try db.prepare(query) {
            results.append(Attachment(
                id: row[id],
                filename: row[filename],
                mimeType: row[mimeType],
                size: row[size],
                contentId: row[contentId],
                isInline: row[isInline],
                localPath: row[localPath].map { URL(fileURLWithPath: $0) }
            ))
        }
        
        return results
    }
    
    // MARK: - Statistics
    
    func getEmailCount(accountId accountIdValue: String) throws -> Int {
        guard let db = db else { throw DatabaseError.notInitialized }
        return try db.scalar(emails.filter(self.accountId == accountIdValue).count)
    }
    
    func getUnreadCount(accountId accountIdValue: String) throws -> Int {
        guard let db = db else { throw DatabaseError.notInitialized }
        return try db.scalar(emails.filter(self.accountId == accountIdValue && isRead == false).count)
    }
}

enum DatabaseError: LocalizedError {
    case notInitialized
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        }
    }
}
