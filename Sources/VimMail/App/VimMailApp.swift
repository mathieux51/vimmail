import SwiftUI
import UserNotifications
import AppKit

@main
struct VimMailApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var keyboardHandler = KeyboardHandler()
    @StateObject private var accountManager = AccountManager()
    @StateObject private var notificationManager = NotificationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(keyboardHandler)
                .environmentObject(accountManager)
                .environmentObject(notificationManager)
                .preferredColorScheme(appState.colorScheme)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .commands {
            VimMailCommands(appState: appState, keyboardHandler: keyboardHandler)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(accountManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let emailId = response.notification.request.content.userInfo["emailId"] as? String
        NotificationCenter.default.post(
            name: .openEmailFromNotification,
            object: nil,
            userInfo: ["emailId": emailId ?? ""]
        )
        completionHandler()
    }
}

// MARK: - Menu Commands
struct VimMailCommands: Commands {
    @ObservedObject var appState: AppState
    @ObservedObject var keyboardHandler: KeyboardHandler
    
    var body: some Commands {
        // File menu
        CommandGroup(replacing: .newItem) {
            Button("New Message") {
                appState.isComposing = true
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Divider()
            
            Button("Close Window") {
                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        
        // Edit menu
        CommandGroup(after: .pasteboard) {
            Divider()
            
            Button("Search") {
                appState.enterSearchMode()
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        
        // View menu
        CommandMenu("View") {
            Button("Toggle Dark Mode") {
                appState.toggleColorScheme()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Zoom In") {
                appState.zoomIn()
            }
            .keyboardShortcut("+", modifiers: .command)
            
            Button("Zoom Out") {
                appState.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)
            
            Button("Reset Zoom") {
                appState.resetZoom()
            }
            .keyboardShortcut("0", modifiers: .command)
            
            Divider()
            
            Button("Toggle Preview Theme") {
                appState.togglePreviewTheme()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }
        
        // Message menu
        CommandMenu("Message") {
            Button("Reply") {
                keyboardHandler.onAction?(.reply)
            }
            .keyboardShortcut("r", modifiers: .command)
            
            Button("Reply All") {
                keyboardHandler.onAction?(.replyAll)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            
            Button("Forward") {
                keyboardHandler.onAction?(.forward)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Archive") {
                keyboardHandler.onAction?(.archive)
            }
            .keyboardShortcut("e", modifiers: .command)
            
            Button("Delete") {
                keyboardHandler.onAction?(.deleteEmail)
            }
            .keyboardShortcut(.delete, modifiers: .command)
            
            Divider()
            
            Button("Mark as Spam") {
                keyboardHandler.onAction?(.reportSpam)
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])
        }
        
        // Help menu
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") {
                appState.showShortcutHelp = true
            }
            .keyboardShortcut("/", modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let openEmailFromNotification = Notification.Name("openEmailFromNotification")
}
