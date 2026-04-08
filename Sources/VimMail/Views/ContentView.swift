import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var keyboardHandler: KeyboardHandler
    @EnvironmentObject var accountManager: AccountManager
    
    @StateObject private var emailViewModel = EmailListViewModel()
    
    var body: some View {
        ZStack {
            NordTheme.Semantic.background
                .ignoresSafeArea()
            
            HSplitView {
                // Sidebar
                SidebarView()
                    .frame(minWidth: 200, maxWidth: 280)
                
                // Email list
                EmailListView()
                    .environmentObject(emailViewModel)
                    .frame(minWidth: 300)
                
                // Detail/Preview
                EmailDetailView()
                    .environmentObject(emailViewModel)
                    .frame(minWidth: 400)
            }
            
            // Command bar overlay
            if appState.vimMode == .command || appState.vimMode == .search {
                VStack {
                    Spacer()
                    CommandBar()
                }
            }
            
            // Shortcut help overlay
            if appState.showShortcutHelp {
                ShortcutHelpView()
            }
            
            // Compose modal
            if appState.isComposing {
                ComposeView()
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .onAppear {
            setupKeyboardHandler()
        }
        .background(KeyEventHandler(handler: keyboardHandler, mode: appState.vimMode))
    }
    
    private func setupKeyboardHandler() {
        keyboardHandler.onAction = { action in
            handleKeyAction(action)
        }
    }
    
    private func handleKeyAction(_ action: KeyAction) {
        switch action {
        case .enterNormalMode:
            appState.enterNormalMode()
        case .enterInsertMode:
            appState.enterInsertMode()
        case .enterCommandMode:
            appState.enterCommandMode()
        case .enterSearchMode:
            appState.enterSearchMode()
        case .showHelp:
            appState.showShortcutHelp.toggle()
        case .compose:
            appState.isComposing = true
        case .zoomIn:
            appState.zoomIn()
        case .zoomOut:
            appState.zoomOut()
        case .resetZoom:
            appState.resetZoom()
        case .togglePreviewTheme:
            appState.togglePreviewTheme()
        case .executeCommand:
            appState.executeCommand()
        case .switchAccount(let index):
            if index < accountManager.accounts.count {
                appState.selectedAccountId = accountManager.accounts[index].id
            }
        default:
            // Pass to email view model
            emailViewModel.handleAction(action)
        }
    }
}

// MARK: - Key Event Handler
struct KeyEventHandler: NSViewRepresentable {
    let handler: KeyboardHandler
    let mode: VimMode
    
    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.handler = handler
        view.mode = mode
        return view
    }
    
    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.handler = handler
        nsView.mode = mode
    }
}

class KeyEventView: NSView {
    var handler: KeyboardHandler?
    var mode: VimMode = .normal
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        Task { @MainActor in
            let handled = handler?.handleKeyDown(event: event, mode: mode) ?? false
            if !handled {
                super.keyDown(with: event)
            }
        }
    }
    
    override func keyUp(with event: NSEvent) {
        Task { @MainActor in
            handler?.handleKeyUp(event: event)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        true
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var accountManager: AccountManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Account selector
            AccountSelector()
                .padding()
            
            Divider()
                .background(NordTheme.Semantic.divider)
            
            // Folders
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    FolderRow(name: "Inbox", icon: "tray", count: 12, isSelected: true)
                    FolderRow(name: "Starred", icon: "star", count: 0, isSelected: false)
                    FolderRow(name: "Sent", icon: "paperplane", count: 0, isSelected: false)
                    FolderRow(name: "Drafts", icon: "doc.text", count: 2, isSelected: false)
                    FolderRow(name: "Spam", icon: "exclamationmark.shield", count: 0, isSelected: false)
                    FolderRow(name: "Trash", icon: "trash", count: 0, isSelected: false)
                    
                    Divider()
                        .background(NordTheme.Semantic.divider)
                        .padding(.vertical, 8)
                    
                    Text("Labels")
                        .font(.caption)
                        .foregroundColor(NordTheme.Semantic.textMuted)
                        .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            // Mode indicator
            ModeIndicator()
                .padding()
        }
        .background(NordTheme.Semantic.backgroundSecondary)
    }
}

struct AccountSelector: View {
    @EnvironmentObject var accountManager: AccountManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    if let account = accountManager.accounts.first {
                        Circle()
                            .fill(Color(hex: account.avatarColor))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(account.initials)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(account.name)
                                .font(.subheadline.bold())
                                .foregroundColor(NordTheme.Semantic.textPrimary)
                            Text(account.email)
                                .font(.caption)
                                .foregroundColor(NordTheme.Semantic.textMuted)
                        }
                    } else {
                        Text("Add Account")
                            .foregroundColor(NordTheme.Semantic.accent)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(NordTheme.Semantic.textMuted)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(accountManager.accounts.dropFirst()) { account in
                    Button(action: {
                        // Switch account
                        isExpanded = false
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: account.avatarColor))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(account.initials)
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                )
                            
                            Text(account.email)
                                .font(.caption)
                                .foregroundColor(NordTheme.Semantic.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                
                Button(action: {
                    accountManager.startGoogleAuth()
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Account")
                    }
                    .font(.caption)
                    .foregroundColor(NordTheme.Semantic.accent)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
    }
}

struct FolderRow: View {
    let name: String
    let icon: String
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(isSelected ? NordTheme.Semantic.accent : NordTheme.Semantic.textSecondary)
            
            Text(name)
                .foregroundColor(isSelected ? NordTheme.Semantic.textPrimary : NordTheme.Semantic.textSecondary)
            
            Spacer()
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(NordTheme.Semantic.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(NordTheme.Semantic.backgroundTertiary)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? NordTheme.Semantic.selection : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
}

struct ModeIndicator: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Text(appState.vimMode.rawValue)
                .font(.caption.monospaced().bold())
                .foregroundColor(modeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(modeColor.opacity(0.2))
                .cornerRadius(4)
            
            Spacer()
            
            if !appState.statusMessage.isEmpty {
                Text(appState.statusMessage)
                    .font(.caption.monospaced())
                    .foregroundColor(NordTheme.Semantic.textMuted)
            }
        }
    }
    
    private var modeColor: Color {
        switch appState.vimMode {
        case .normal:
            return NordTheme.nord14
        case .insert:
            return NordTheme.nord13
        case .visual:
            return NordTheme.nord15
        case .command:
            return NordTheme.nord8
        case .search:
            return NordTheme.nord12
        }
    }
}

// MARK: - Command Bar
struct CommandBar: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Text(appState.commandBuffer)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(NordTheme.Semantic.textPrimary)
            
            Rectangle()
                .fill(NordTheme.Semantic.accent)
                .frame(width: 8, height: 18)
                .opacity(0.8)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(NordTheme.Semantic.backgroundSecondary)
        .overlay(
            Rectangle()
                .stroke(NordTheme.Semantic.border, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(KeyboardHandler())
        .environmentObject(AccountManager())
        .environmentObject(NotificationManager())
}
