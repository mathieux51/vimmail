import SwiftUI
import Combine
import Carbon.HIToolbox

// MARK: - Keyboard Handler
@MainActor
class KeyboardHandler: ObservableObject {
    @Published var currentKeys: Set<KeyCode> = []
    @Published var keySequence: [KeyCode] = []
    @Published var lastCommand: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private var sequenceTimer: Timer?
    private let sequenceTimeout: TimeInterval = 1.0
    
    // Key bindings registry
    private var normalModeBindings: [KeyBinding] = []
    private var insertModeBindings: [KeyBinding] = []
    private var commandModeBindings: [KeyBinding] = []
    
    var onAction: ((KeyAction) -> Void)?
    
    init() {
        setupDefaultBindings()
    }
    
    // MARK: - Key Event Handling
    
    func handleKeyDown(event: NSEvent, mode: VimMode) -> Bool {
        let keyCode = KeyCode(rawValue: Int(event.keyCode)) ?? .unknown
        let modifiers = KeyModifiers(event: event)
        
        currentKeys.insert(keyCode)
        
        // Handle escape - always returns to normal mode
        if keyCode == .escape {
            onAction?(.enterNormalMode)
            return true
        }
        
        // Handle based on current mode
        switch mode {
        case .normal:
            return handleNormalMode(keyCode: keyCode, modifiers: modifiers)
        case .insert:
            return handleInsertMode(keyCode: keyCode, modifiers: modifiers)
        case .command:
            return handleCommandMode(keyCode: keyCode, modifiers: modifiers)
        case .search:
            return handleSearchMode(keyCode: keyCode, modifiers: modifiers)
        case .visual:
            return handleVisualMode(keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    func handleKeyUp(event: NSEvent) {
        let keyCode = KeyCode(rawValue: Int(event.keyCode)) ?? .unknown
        currentKeys.remove(keyCode)
    }
    
    // MARK: - Normal Mode
    
    private func handleNormalMode(keyCode: KeyCode, modifiers: KeyModifiers) -> Bool {
        // Add to sequence for multi-key commands
        keySequence.append(keyCode)
        resetSequenceTimer()
        
        // Check for key sequence commands first (e.g., "gg", "dd")
        if let action = checkSequence() {
            onAction?(action)
            keySequence.removeAll()
            return true
        }
        
        // Single key commands
        switch keyCode {
        // Navigation
        case .j:
            onAction?(.moveDown)
        case .k:
            onAction?(.moveUp)
        case .h:
            if modifiers.ctrl {
                onAction?(.focusSidebar)
            } else {
                onAction?(.moveLeft)
            }
        case .l:
            if modifiers.ctrl {
                onAction?(.focusDetail)
            } else {
                onAction?(.moveRight)
            }
        case .g:
            // Wait for second key
            return true
        case .returnKey, .enter:
            onAction?(.openEmail)
        
        // Mode switching
        case .i:
            onAction?(.enterInsertMode)
        case .colon:
            onAction?(.enterCommandMode)
        case .slash:
            onAction?(.enterSearchMode)
        case .v:
            onAction?(.enterVisualMode)
        
        // Actions
        case .d:
            if modifiers.shift {
                onAction?(.deleteEmail)
            }
            // Wait for second d
            return true
        case .r:
            if modifiers.shift {
                onAction?(.replyAll)
            } else {
                onAction?(.reply)
            }
        case .f:
            onAction?(.forward)
        case .s:
            onAction?(.toggleStar)
        case .a:
            onAction?(.archive)
        case .x:
            onAction?(.toggleSelect)
        case .u:
            onAction?(.markUnread)
        case .e:
            onAction?(.reportSpam)
        case .num0:
            onAction?(.block)
            
        // Zoom
        case .plus, .equals:
            if modifiers.cmd {
                onAction?(.zoomIn)
            }
        case .minus:
            if modifiers.cmd {
                onAction?(.zoomOut)
            }
        
        // Preview toggle
        case .p:
            onAction?(.togglePreview)
        case .t:
            onAction?(.togglePreviewTheme)
        
        // Compose
        case .c:
            onAction?(.compose)
        
        // Refresh
        case .period:
            if modifiers.ctrl {
                onAction?(.refresh)
            }
        
        // Shortcuts help
        case .questionMark:
            onAction?(.showHelp)
        
        // Attachment
        case .o:
            onAction?(.openAttachment)
        
        // Account switching
        case .num1, .num2, .num3, .num4, .num5, .num6, .num7, .num8, .num9:
            let accountIndex = keyCode.rawValue - KeyCode.num1.rawValue
            onAction?(.switchAccount(index: accountIndex))
        
        // Tab navigation
        case .tab:
            if modifiers.shift {
                onAction?(.previousPanel)
            } else {
                onAction?(.nextPanel)
            }
        
        default:
            keySequence.removeLast()
            return false
        }
        
        return true
    }
    
    // MARK: - Insert Mode
    
    private func handleInsertMode(keyCode: KeyCode, modifiers: KeyModifiers) -> Bool {
        // Ctrl+Space for autocomplete
        if modifiers.ctrl && keyCode == .space {
            onAction?(.triggerAutocomplete)
            return true
        }
        
        // Tab to accept autocomplete
        if keyCode == .tab {
            onAction?(.acceptAutocomplete)
            return true
        }
        
        // Cmd+Enter to send
        if modifiers.cmd && (keyCode == .returnKey || keyCode == .enter) {
            onAction?(.send)
            return true
        }
        
        // Cmd+S to save draft
        if modifiers.cmd && keyCode == .s {
            onAction?(.saveDraft)
            return true
        }
        
        // Cmd+Shift+A to attach
        if modifiers.cmd && modifiers.shift && keyCode == .a {
            onAction?(.attachFile)
            return true
        }
        
        // Let normal typing through
        return false
    }
    
    // MARK: - Command Mode
    
    private func handleCommandMode(keyCode: KeyCode, modifiers: KeyModifiers) -> Bool {
        if keyCode == .returnKey || keyCode == .enter {
            onAction?(.executeCommand)
            return true
        }
        
        if keyCode == .backspace && modifiers.isEmpty {
            onAction?(.deleteCommandChar)
            return true
        }
        
        return false
    }
    
    // MARK: - Search Mode
    
    private func handleSearchMode(keyCode: KeyCode, modifiers: KeyModifiers) -> Bool {
        if keyCode == .returnKey || keyCode == .enter {
            onAction?(.executeSearch)
            return true
        }
        
        if keyCode == .n {
            if modifiers.shift {
                onAction?(.previousSearchResult)
            } else {
                onAction?(.nextSearchResult)
            }
            return true
        }
        
        return false
    }
    
    // MARK: - Visual Mode
    
    private func handleVisualMode(keyCode: KeyCode, modifiers: KeyModifiers) -> Bool {
        switch keyCode {
        case .j:
            onAction?(.extendSelectionDown)
        case .k:
            onAction?(.extendSelectionUp)
        case .d:
            onAction?(.deleteSelected)
        case .a:
            onAction?(.archiveSelected)
        case .s:
            onAction?(.starSelected)
        case .u:
            onAction?(.markSelectedUnread)
        default:
            return false
        }
        return true
    }
    
    // MARK: - Key Sequences
    
    private func checkSequence() -> KeyAction? {
        let seq = keySequence
        
        // gg - go to top
        if seq.count >= 2 && seq.suffix(2) == [.g, .g] {
            return .goToTop
        }
        
        // G - go to bottom
        if seq.last == .g && currentKeys.contains(.shift) {
            keySequence.removeLast()
            return .goToBottom
        }
        
        // dd - delete
        if seq.count >= 2 && seq.suffix(2) == [.d, .d] {
            return .deleteEmail
        }
        
        // zz - center current
        if seq.count >= 2 && seq.suffix(2) == [.z, .z] {
            return .centerCurrent
        }
        
        // / followed by text - search
        if seq.first == .slash {
            return nil // Continue building search
        }
        
        return nil
    }
    
    private func resetSequenceTimer() {
        sequenceTimer?.invalidate()
        sequenceTimer = Timer.scheduledTimer(withTimeInterval: sequenceTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.keySequence.removeAll()
            }
        }
    }
    
    // MARK: - Default Bindings
    
    private func setupDefaultBindings() {
        // These can be loaded from user preferences
    }
}

// MARK: - Key Types

enum KeyCode: Int {
    case unknown = -1
    case a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9
    case b = 11, q = 12, w = 13, e = 14, r = 15, y = 16, t = 17
    case num1 = 18, num2 = 19, num3 = 20, num4 = 21, num6 = 22, num5 = 23, equals = 24
    case num9 = 25, num7 = 26, minus = 27, num8 = 28, num0 = 29
    case o = 31, u = 32, i = 34, p = 35, l = 37, j = 38, k = 40, n = 45, m = 46
    case returnKey = 36, tab = 48, space = 49, backspace = 51, escape = 53
    case enter = 76
    case slash = 44, colon = 41
    case period = 47, plus = 69
    case questionMark = 191
    
    case leftArrow = 123, rightArrow = 124, downArrow = 125, upArrow = 126
    case shift = 56
}

struct KeyModifiers {
    let cmd: Bool
    let ctrl: Bool
    let alt: Bool
    let shift: Bool
    
    var isEmpty: Bool {
        !cmd && !ctrl && !alt && !shift
    }
    
    init(event: NSEvent) {
        cmd = event.modifierFlags.contains(.command)
        ctrl = event.modifierFlags.contains(.control)
        alt = event.modifierFlags.contains(.option)
        shift = event.modifierFlags.contains(.shift)
    }
}

struct KeyBinding: Identifiable {
    let id = UUID()
    let keys: [KeyCode]
    let modifiers: KeyModifiers?
    let action: KeyAction
    let description: String
}

// MARK: - Key Actions

enum KeyAction {
    // Mode changes
    case enterNormalMode
    case enterInsertMode
    case enterCommandMode
    case enterSearchMode
    case enterVisualMode
    
    // Navigation
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
    case goToTop
    case goToBottom
    case centerCurrent
    case nextPanel
    case previousPanel
    case focusSidebar
    case focusDetail
    case focusEmailList
    
    // Email actions
    case openEmail
    case reply
    case replyAll
    case forward
    case deleteEmail
    case archive
    case toggleStar
    case toggleSelect
    case markUnread
    case reportSpam
    case block
    
    // Compose
    case compose
    case send
    case saveDraft
    case attachFile
    
    // View
    case togglePreview
    case togglePreviewTheme
    case zoomIn
    case zoomOut
    case resetZoom
    case refresh
    case showHelp
    
    // Autocomplete
    case triggerAutocomplete
    case acceptAutocomplete
    case dismissAutocomplete
    
    // Search
    case executeSearch
    case nextSearchResult
    case previousSearchResult
    
    // Command
    case executeCommand
    case deleteCommandChar
    
    // Selection
    case extendSelectionUp
    case extendSelectionDown
    case deleteSelected
    case archiveSelected
    case starSelected
    case markSelectedUnread
    
    // Attachments
    case openAttachment
    
    // Accounts
    case switchAccount(index: Int)
}
