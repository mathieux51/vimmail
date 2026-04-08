import Foundation
import UserNotifications
import AppKit

// MARK: - Notification Manager
@MainActor
class NotificationManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var pendingNotifications: [String] = []
    
    private var center: UNUserNotificationCenter?
    
    init() {
        // Only initialize notification center if running as a proper app bundle
        if Bundle.main.bundleIdentifier != nil {
            center = UNUserNotificationCenter.current()
            checkAuthorization()
        }
    }
    
    func checkAuthorization() {
        center?.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        guard let center = center else { return false }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    // MARK: - Send Notifications
    
    func notifyNewEmail(_ email: Email) {
        guard isAuthorized, let center = center else { return }
        
        let content = UNMutableNotificationContent()
        content.title = email.from.displayName
        content.subtitle = email.subject
        content.body = email.snippet
        content.sound = .default
        content.userInfo = [
            "emailId": email.id,
            "accountId": email.accountId,
            "threadId": email.threadId
        ]
        
        // Add category for actions
        content.categoryIdentifier = "NEW_EMAIL"
        
        let request = UNNotificationRequest(
            identifier: email.id,
            content: content,
            trigger: nil
        )
        
        center.add(request)
    }
    
    func notifyBatchEmails(count: Int, accountEmail: String) {
        guard isAuthorized, let center = center else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New Emails"
        content.body = "\(count) new emails in \(accountEmail)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "batch-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        center.add(request)
    }
    
    // MARK: - Badge Management
    
    func updateBadge(count: Int) {
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }
    
    // MARK: - Notification Categories
    
    func registerCategories() {
        guard let center = center else { return }
        
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ",
            title: "Mark as Read",
            options: []
        )
        
        let archiveAction = UNNotificationAction(
            identifier: "ARCHIVE",
            title: "Archive",
            options: []
        )
        
        let replyAction = UNNotificationAction(
            identifier: "REPLY",
            title: "Reply",
            options: .foreground
        )
        
        let deleteAction = UNNotificationAction(
            identifier: "DELETE",
            title: "Delete",
            options: .destructive
        )
        
        let newEmailCategory = UNNotificationCategory(
            identifier: "NEW_EMAIL",
            actions: [markReadAction, archiveAction, replyAction, deleteAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([newEmailCategory])
    }
    
    // MARK: - Clear Notifications
    
    func clearNotification(for emailId: String) {
        center?.removeDeliveredNotifications(withIdentifiers: [emailId])
    }
    
    func clearAllNotifications() {
        center?.removeAllDeliveredNotifications()
    }
}
