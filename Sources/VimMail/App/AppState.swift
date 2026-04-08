import SwiftUI
import Combine

// MARK: - Vim Mode
enum VimMode: String {
    case normal = "NORMAL"
    case insert = "INSERT"
    case visual = "VISUAL"
    case command = "COMMAND"
    case search = "SEARCH"
}

// MARK: - Navigation Focus
enum NavigationFocus: Hashable {
    case sidebar
    case emailList
    case emailDetail
    case composer
    case search
    case attachmentPicker
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var vimMode: VimMode = .normal
    @Published var focus: NavigationFocus = .emailList
    @Published var colorScheme: ColorScheme? = .dark
    @Published var showCommandPalette = false
    @Published var commandBuffer = ""
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var showShortcutHelp = false
    @Published var previewZoom: CGFloat = 1.0
    @Published var usesDarkPreview = true
    @Published var selectedAccountId: String?
    @Published var selectedFolderId: String?
    @Published var selectedEmailId: String?
    @Published var isComposing = false
    @Published var replyingToEmailId: String?
    @Published var statusMessage = ""
    @Published var pendingCount = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadPreferences()
    }
    
    func loadPreferences() {
        if let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") {
            colorScheme = savedScheme == "dark" ? .dark : .light
        }
        usesDarkPreview = UserDefaults.standard.bool(forKey: "usesDarkPreview")
        previewZoom = UserDefaults.standard.double(forKey: "previewZoom")
        if previewZoom == 0 { previewZoom = 1.0 }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(colorScheme == .dark ? "dark" : "light", forKey: "colorScheme")
        UserDefaults.standard.set(usesDarkPreview, forKey: "usesDarkPreview")
        UserDefaults.standard.set(previewZoom, forKey: "previewZoom")
    }
    
    func toggleColorScheme() {
        colorScheme = colorScheme == .dark ? .light : .dark
        savePreferences()
    }
    
    func togglePreviewTheme() {
        usesDarkPreview.toggle()
        savePreferences()
    }
    
    func zoomIn() {
        previewZoom = min(previewZoom + 0.1, 3.0)
        savePreferences()
    }
    
    func zoomOut() {
        previewZoom = max(previewZoom - 0.1, 0.5)
        savePreferences()
    }
    
    func resetZoom() {
        previewZoom = 1.0
        savePreferences()
    }
    
    func enterInsertMode() {
        vimMode = .insert
        statusMessage = "-- INSERT --"
    }
    
    func enterNormalMode() {
        vimMode = .normal
        statusMessage = ""
        commandBuffer = ""
    }
    
    func enterCommandMode() {
        vimMode = .command
        commandBuffer = ":"
    }
    
    func enterSearchMode() {
        vimMode = .search
        commandBuffer = "/"
        isSearching = true
    }
    
    func executeCommand() {
        let command = String(commandBuffer.dropFirst())
        switch command {
        case "q", "quit":
            NSApplication.shared.terminate(nil)
        case "w", "write":
            statusMessage = "Saved"
        case "wq":
            statusMessage = "Saved and quit"
            NSApplication.shared.terminate(nil)
        case "help", "h":
            showShortcutHelp = true
        case "set dark", "dark":
            colorScheme = .dark
            savePreferences()
        case "set light", "light":
            colorScheme = .light
            savePreferences()
        case "compose", "c":
            isComposing = true
        case "search", "s":
            enterSearchMode()
        default:
            if command.hasPrefix("zoom ") {
                if let zoom = Double(command.dropFirst(5)) {
                    previewZoom = max(0.5, min(3.0, zoom))
                    savePreferences()
                }
            } else {
                statusMessage = "Unknown command: \(command)"
            }
        }
        enterNormalMode()
    }
}
