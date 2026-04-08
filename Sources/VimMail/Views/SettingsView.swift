import SwiftUI

// MARK: - Shortcut Help View
struct ShortcutHelpView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.showShortcutHelp = false
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.title2.bold())
                        .foregroundColor(NordTheme.Semantic.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { appState.showShortcutHelp = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(NordTheme.Semantic.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(NordTheme.Semantic.backgroundSecondary)
                
                Divider()
                
                // Shortcuts grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ShortcutSection(title: "Navigation", shortcuts: [
                            Shortcut(keys: ["j"], description: "Move down"),
                            Shortcut(keys: ["k"], description: "Move up"),
                            Shortcut(keys: ["g", "g"], description: "Go to top"),
                            Shortcut(keys: ["G"], description: "Go to bottom"),
                            Shortcut(keys: ["Enter"], description: "Open email"),
                            Shortcut(keys: ["Tab"], description: "Next panel"),
                            Shortcut(keys: ["Shift", "Tab"], description: "Previous panel"),
                            Shortcut(keys: ["Ctrl", "h"], description: "Focus sidebar"),
                            Shortcut(keys: ["Ctrl", "l"], description: "Focus detail"),
                        ])
                        
                        ShortcutSection(title: "Mode Switching", shortcuts: [
                            Shortcut(keys: ["i"], description: "Enter insert mode"),
                            Shortcut(keys: ["Esc"], description: "Enter normal mode"),
                            Shortcut(keys: [":"], description: "Enter command mode"),
                            Shortcut(keys: ["/"], description: "Search mode"),
                            Shortcut(keys: ["v"], description: "Visual mode (multi-select)"),
                        ])
                        
                        ShortcutSection(title: "Email Actions", shortcuts: [
                            Shortcut(keys: ["r"], description: "Reply"),
                            Shortcut(keys: ["R"], description: "Reply all"),
                            Shortcut(keys: ["f"], description: "Forward"),
                            Shortcut(keys: ["c"], description: "Compose new"),
                            Shortcut(keys: ["a"], description: "Archive"),
                            Shortcut(keys: ["d", "d"], description: "Delete"),
                            Shortcut(keys: ["s"], description: "Toggle star"),
                            Shortcut(keys: ["u"], description: "Mark unread"),
                            Shortcut(keys: ["e"], description: "Report spam"),
                            Shortcut(keys: ["!"], description: "Block sender"),
                            Shortcut(keys: ["x"], description: "Select/deselect"),
                        ])
                        
                        ShortcutSection(title: "View Controls", shortcuts: [
                            Shortcut(keys: ["Cmd", "+"], description: "Zoom in preview"),
                            Shortcut(keys: ["Cmd", "-"], description: "Zoom out preview"),
                            Shortcut(keys: ["t"], description: "Toggle dark/light preview"),
                            Shortcut(keys: ["p"], description: "Toggle preview panel"),
                            Shortcut(keys: ["?"], description: "Show/hide this help"),
                        ])
                        
                        ShortcutSection(title: "Compose Mode", shortcuts: [
                            Shortcut(keys: ["Cmd", "Enter"], description: "Send email"),
                            Shortcut(keys: ["Cmd", "S"], description: "Save draft"),
                            Shortcut(keys: ["Ctrl", "Space"], description: "AI autocomplete"),
                            Shortcut(keys: ["Tab"], description: "Accept autocomplete"),
                            Shortcut(keys: ["Cmd", "Shift", "A"], description: "Attach file"),
                        ])
                        
                        ShortcutSection(title: "Attachments", shortcuts: [
                            Shortcut(keys: ["o"], description: "Open attachment"),
                            Shortcut(keys: ["Cmd", "Shift", "A"], description: "Fuzzy file search"),
                        ])
                        
                        ShortcutSection(title: "Accounts", shortcuts: [
                            Shortcut(keys: ["1-9"], description: "Switch to account N"),
                        ])
                        
                        ShortcutSection(title: "Commands", shortcuts: [
                            Shortcut(keys: [":q"], description: "Quit"),
                            Shortcut(keys: [":help"], description: "Show help"),
                            Shortcut(keys: [":dark"], description: "Dark mode"),
                            Shortcut(keys: [":light"], description: "Light mode"),
                            Shortcut(keys: [":zoom N"], description: "Set zoom level"),
                        ])
                    }
                    .padding()
                }
            }
            .frame(width: 600, height: 500)
            .background(NordTheme.Semantic.background)
            .cornerRadius(12)
            .shadow(color: NordTheme.Semantic.shadow, radius: 20)
        }
    }
}

// MARK: - Shortcut Section
struct ShortcutSection: View {
    let title: String
    let shortcuts: [Shortcut]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(NordTheme.Semantic.accent)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 8) {
                ForEach(shortcuts) { shortcut in
                    ShortcutRow(shortcut: shortcut)
                }
            }
        }
    }
}

struct Shortcut: Identifiable {
    let id = UUID()
    let keys: [String]
    let description: String
}

struct ShortcutRow: View {
    let shortcut: Shortcut
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(shortcut.keys, id: \.self) { key in
                    Text(key)
                        .font(.caption.monospaced().bold())
                        .foregroundColor(NordTheme.Semantic.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(NordTheme.Semantic.backgroundTertiary)
                        .cornerRadius(4)
                }
            }
            .frame(minWidth: 80, alignment: .leading)
            
            Text(shortcut.description)
                .font(.caption)
                .foregroundColor(NordTheme.Semantic.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var accountManager: AccountManager
    
    @State private var claudeApiKey = ""
    @State private var selectedTab = "accounts"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Accounts tab
            AccountsSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.2")
                }
                .tag("accounts")
            
            // Appearance tab
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
                .tag("appearance")
            
            // AI tab
            AISettingsView(apiKey: $claudeApiKey)
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag("ai")
            
            // Filters tab
            FiltersSettingsView()
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .tag("filters")
            
            // Shortcuts tab
            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag("shortcuts")
        }
        .frame(width: 600, height: 400)
    }
}

// MARK: - Accounts Settings
struct AccountsSettingsView: View {
    @EnvironmentObject var accountManager: AccountManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected Accounts")
                .font(.headline)
            
            ForEach(accountManager.accounts) { account in
                HStack {
                    Circle()
                        .fill(Color(hex: account.avatarColor))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(account.initials)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(account.name)
                            .font(.subheadline.bold())
                        Text(account.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Remove") {
                        accountManager.removeAccount(account.id)
                    }
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: {
                accountManager.startGoogleAuth()
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Google Account")
                }
            }
            .buttonStyle(NordButtonStyle(variant: .primary))
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var fontSize: Double = 14
    @State private var showLineNumbers = true
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Color Scheme", selection: Binding(
                    get: { appState.colorScheme == .dark },
                    set: { appState.colorScheme = $0 ? .dark : .light }
                )) {
                    Text("Light").tag(false)
                    Text("Dark").tag(true)
                }
                .pickerStyle(.segmented)
                
                Toggle("Dark email preview by default", isOn: $appState.usesDarkPreview)
            }
            
            Section("Email Preview") {
                HStack {
                    Text("Default Zoom")
                    Slider(value: $appState.previewZoom, in: 0.5...2.0, step: 0.1)
                    Text("\(Int(appState.previewZoom * 100))%")
                        .frame(width: 50)
                }
            }
        }
        .padding()
    }
}

// MARK: - AI Settings
struct AISettingsView: View {
    @Binding var apiKey: String
    @State private var model = "claude-sonnet-4-20250514"
    @State private var enableAutocomplete = true
    @State private var enableSuggestions = true
    
    var body: some View {
        Form {
            Section("Claude API") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Model", selection: $model) {
                    Text("Claude Sonnet").tag("claude-sonnet-4-20250514")
                    Text("Claude Opus").tag("claude-opus-4-20250514")
                }
            }
            
            Section("Features") {
                Toggle("Enable autocomplete", isOn: $enableAutocomplete)
                Toggle("Enable reply suggestions", isOn: $enableSuggestions)
            }
        }
        .padding()
    }
}

// MARK: - Filters Settings
struct FiltersSettingsView: View {
    @State private var rules: [FilterRule] = []
    @State private var showingAddRule = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Email Filters")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddRule = true }) {
                    Image(systemName: "plus")
                }
            }
            
            if rules.isEmpty {
                Text("No filters configured")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(rules) { rule in
                        HStack {
                            Toggle("", isOn: .constant(rule.isEnabled))
                                .labelsHidden()
                            
                            VStack(alignment: .leading) {
                                Text(rule.name)
                                    .font(.subheadline.bold())
                                Text("\(rule.conditions.count) conditions, \(rule.actions.count) actions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { _ in }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Shortcuts Settings
struct ShortcutsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            
            Text("Shortcuts follow vim-style conventions and cannot be customized yet.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("View All Shortcuts") {
                // Show shortcuts overlay
            }
            
            Spacer()
        }
        .padding()
    }
}
