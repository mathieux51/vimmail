import XCTest
@testable import VimMail

final class VimMailTests: XCTestCase {
    
    func testNordThemeColors() {
        // Test that Nord colors are properly defined
        XCTAssertNotNil(NordTheme.nord0)
        XCTAssertNotNil(NordTheme.Semantic.background)
        XCTAssertNotNil(NordTheme.Semantic.accent)
    }
    
    func testEmailAddress() {
        let address = EmailAddress(name: "John Doe", email: "john@example.com")
        XCTAssertEqual(address.displayName, "John Doe")
        XCTAssertEqual(address.displayString, "John Doe <john@example.com>")
        XCTAssertEqual(address.domain, "example.com")
    }
    
    func testEmailAddressWithoutName() {
        let address = EmailAddress(name: nil, email: "john@example.com")
        XCTAssertEqual(address.displayName, "john@example.com")
        XCTAssertEqual(address.displayString, "john@example.com")
    }
    
    func testFilterConditionContains() {
        let condition = FilterRule.FilterCondition(
            field: .subject,
            matchType: .contains,
            value: "urgent"
        )
        
        let email = createTestEmail(subject: "This is URGENT!")
        XCTAssertTrue(condition.matches(email: email))
        
        let normalEmail = createTestEmail(subject: "Normal email")
        XCTAssertFalse(condition.matches(email: normalEmail))
    }
    
    func testFilterConditionRegex() {
        let condition = FilterRule.FilterCondition(
            field: .from,
            matchType: .regex,
            value: ".*@example\\.com"
        )
        
        let email = createTestEmail(fromEmail: "test@example.com")
        XCTAssertTrue(condition.matches(email: email))
        
        let otherEmail = createTestEmail(fromEmail: "test@other.com")
        XCTAssertFalse(condition.matches(email: otherEmail))
    }
    
    func testSenderTrustLevel() {
        var email = createTestEmail()
        email.spfStatus = .pass
        email.dkimStatus = .pass
        XCTAssertEqual(email.senderTrustLevel, .verified)
        
        var suspiciousEmail = createTestEmail()
        suspiciousEmail.spfStatus = .fail
        XCTAssertEqual(suspiciousEmail.senderTrustLevel, .suspicious)
        
        var unknownEmail = createTestEmail()
        unknownEmail.spfStatus = .none
        XCTAssertEqual(unknownEmail.senderTrustLevel, .unknown)
    }
    
    func testAttachmentFormatting() {
        let attachment = Attachment(
            id: "1",
            filename: "report.pdf",
            mimeType: "application/pdf",
            size: 1024 * 1024,
            contentId: nil,
            isInline: false,
            localPath: nil
        )
        
        XCTAssertEqual(attachment.formattedSize, "1 MB")
        XCTAssertTrue(attachment.isPDF)
        XCTAssertFalse(attachment.isImage)
        XCTAssertEqual(attachment.iconName, "doc.richtext")
    }
    
    // MARK: - Helpers
    
    private func createTestEmail(
        subject: String = "Test Subject",
        fromEmail: String = "sender@test.com",
        fromName: String? = "Test Sender"
    ) -> Email {
        Email(
            id: UUID().uuidString,
            threadId: "thread1",
            accountId: "account1",
            messageId: "msg1",
            from: EmailAddress(name: fromName, email: fromEmail),
            to: [EmailAddress(name: "Recipient", email: "recipient@test.com")],
            cc: [],
            bcc: [],
            replyTo: [],
            subject: subject,
            snippet: "Test snippet",
            bodyPlain: "Test body",
            bodyHtml: nil,
            date: Date(),
            receivedDate: Date(),
            isRead: false,
            isStarred: false,
            isSpam: false,
            isTrash: false,
            isDraft: false,
            isSent: false,
            labels: ["INBOX"],
            attachments: [],
            inReplyTo: nil,
            references: [],
            spfStatus: nil,
            dkimStatus: nil,
            dmarcStatus: nil,
            isEncrypted: false
        )
    }
}
