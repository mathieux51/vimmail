import SwiftUI

// MARK: - Compose View
struct ComposeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var accountManager: AccountManager
    
    @State private var toField: String = ""
    @State private var ccField: String = ""
    @State private var bccField: String = ""
    @State private var subjectField: String = ""
    @State private var bodyText: String = ""
    @State private var showCcBcc = false
    @State private var attachments: [URL] = []
    @State private var showAttachmentPicker = false
    @State private var showAISuggestions = false
    @State private var aiSuggestions: [SuggestedReply] = []
    @State private var isLoadingSuggestions = false
    @State private var autocompleteText = ""
    @State private var showAutocomplete = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Close on background tap
                }
            
            VStack(spacing: 0) {
                // Header
                ComposeHeader(onClose: close, onSend: send)
                
                Divider()
                    .background(NordTheme.Semantic.divider)
                
                // Recipients
                VStack(spacing: 0) {
                    RecipientField(label: "To:", text: $toField)
                    
                    if showCcBcc {
                        RecipientField(label: "Cc:", text: $ccField)
                        RecipientField(label: "Bcc:", text: $bccField)
                    }
                    
                    HStack {
                        Button(action: { showCcBcc.toggle() }) {
                            Text(showCcBcc ? "Hide Cc/Bcc" : "Show Cc/Bcc")
                                .font(.caption)
                                .foregroundColor(NordTheme.Semantic.accent)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    
                    SubjectField(text: $subjectField)
                }
                
                Divider()
                    .background(NordTheme.Semantic.divider)
                
                // Body editor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $bodyText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .foregroundColor(NordTheme.Semantic.textPrimary)
                        .padding()
                    
                    // Autocomplete overlay
                    if showAutocomplete && !autocompleteText.isEmpty {
                        AutocompleteOverlay(
                            text: autocompleteText,
                            onAccept: acceptAutocomplete,
                            onDismiss: { showAutocomplete = false }
                        )
                    }
                    
                    // Placeholder
                    if bodyText.isEmpty {
                        Text("Write your message... (Ctrl+Space for AI autocomplete)")
                            .foregroundColor(NordTheme.Semantic.textMuted)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
                .background(NordTheme.Semantic.background)
                
                // Attachments
                if !attachments.isEmpty {
                    AttachmentsRow(attachments: attachments, onRemove: removeAttachment)
                }
                
                // AI Suggestions
                if showAISuggestions {
                    AISuggestionsPanel(
                        suggestions: aiSuggestions,
                        isLoading: isLoadingSuggestions,
                        onSelect: applySuggestion,
                        onDismiss: { showAISuggestions = false }
                    )
                }
                
                // Footer toolbar
                ComposeToolbar(
                    onAttach: { showAttachmentPicker = true },
                    onAISuggest: requestAISuggestions,
                    onDiscard: close
                )
            }
            .frame(width: 700, height: 600)
            .background(NordTheme.Semantic.backgroundSecondary)
            .cornerRadius(12)
            .shadow(color: NordTheme.Semantic.shadow, radius: 20)
        }
        .fileImporter(
            isPresented: $showAttachmentPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                attachments.append(contentsOf: urls)
            }
        }
    }
    
    private func close() {
        appState.isComposing = false
    }
    
    private func send() {
        // Send email
        close()
    }
    
    private func removeAttachment(_ url: URL) {
        attachments.removeAll { $0 == url }
    }
    
    private func acceptAutocomplete() {
        bodyText += autocompleteText
        autocompleteText = ""
        showAutocomplete = false
    }
    
    private func requestAISuggestions() {
        showAISuggestions = true
        isLoadingSuggestions = true
        
        // TODO: Call Claude service
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            aiSuggestions = [
                SuggestedReply(tone: "Professional", content: "Thank you for your email. I will review the information and get back to you shortly."),
                SuggestedReply(tone: "Friendly", content: "Thanks for reaching out! I'll take a look and follow up soon."),
                SuggestedReply(tone: "Brief", content: "Noted. Will follow up.")
            ]
            isLoadingSuggestions = false
        }
    }
    
    private func applySuggestion(_ suggestion: SuggestedReply) {
        bodyText = suggestion.content
        showAISuggestions = false
    }
}

// MARK: - Compose Header
struct ComposeHeader: View {
    let onClose: () -> Void
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(NordTheme.Semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            
            Text("New Message")
                .font(.headline)
                .foregroundColor(NordTheme.Semantic.textPrimary)
            
            Spacer()
            
            Button(action: onSend) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                }
            }
            .buttonStyle(NordButtonStyle(variant: .primary))
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
}

// MARK: - Recipient Field
struct RecipientField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(NordTheme.Semantic.textMuted)
                .frame(width: 40, alignment: .trailing)
            
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(NordTheme.Semantic.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        
        Divider()
            .background(NordTheme.Semantic.divider)
    }
}

// MARK: - Subject Field
struct SubjectField: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text("Subject:")
                .font(.subheadline)
                .foregroundColor(NordTheme.Semantic.textMuted)
                .frame(width: 60, alignment: .trailing)
            
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(NordTheme.Semantic.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Autocomplete Overlay
struct AutocompleteOverlay: View {
    let text: String
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .foregroundColor(NordTheme.Semantic.textMuted.opacity(0.7))
                .italic()
            
            HStack {
                Text("Tab to accept")
                    .font(.caption)
                    .foregroundColor(NordTheme.Semantic.textMuted)
                
                Text("Esc to dismiss")
                    .font(.caption)
                    .foregroundColor(NordTheme.Semantic.textMuted)
            }
        }
        .padding()
        .background(NordTheme.Semantic.backgroundTertiary)
        .cornerRadius(8)
        .shadow(radius: 4)
        .padding()
    }
}

// MARK: - Attachments Row
struct AttachmentsRow: View {
    let attachments: [URL]
    let onRemove: (URL) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments, id: \.self) { url in
                    AttachmentChip(url: url, onRemove: { onRemove(url) })
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(NordTheme.Semantic.backgroundTertiary)
    }
}

struct AttachmentChip: View {
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc")
                .foregroundColor(NordTheme.Semantic.attachment)
            
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundColor(NordTheme.Semantic.textPrimary)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(NordTheme.Semantic.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NordTheme.Semantic.backgroundSecondary)
        .cornerRadius(16)
    }
}

// MARK: - AI Suggestions Panel
struct AISuggestionsPanel: View {
    let suggestions: [SuggestedReply]
    let isLoading: Bool
    let onSelect: (SuggestedReply) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(NordTheme.Semantic.accent)
                
                Text("AI Suggestions")
                    .font(.headline)
                    .foregroundColor(NordTheme.Semantic.textPrimary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(NordTheme.Semantic.textMuted)
                }
                .buttonStyle(.plain)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating suggestions...")
                        .font(.caption)
                        .foregroundColor(NordTheme.Semantic.textMuted)
                }
            } else {
                ForEach(suggestions) { suggestion in
                    Button(action: { onSelect(suggestion) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.tone)
                                .font(.caption.bold())
                                .foregroundColor(NordTheme.Semantic.accent)
                            
                            Text(suggestion.content)
                                .font(.caption)
                                .foregroundColor(NordTheme.Semantic.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NordTheme.Semantic.backgroundTertiary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(NordTheme.Semantic.backgroundSecondary)
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Compose Toolbar
struct ComposeToolbar: View {
    let onAttach: () -> Void
    let onAISuggest: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onAttach) {
                HStack {
                    Image(systemName: "paperclip")
                    Text("Attach")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(NordTheme.Semantic.textSecondary)
            
            Button(action: onAISuggest) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("AI Suggest")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(NordTheme.Semantic.accent)
            
            Spacer()
            
            Button(action: onDiscard) {
                HStack {
                    Image(systemName: "trash")
                    Text("Discard")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(NordTheme.Semantic.error)
        }
        .padding()
        .background(NordTheme.Semantic.backgroundTertiary)
    }
}

// MARK: - Fuzzy File Picker
struct FuzzyFilePicker: View {
    @State private var searchQuery = ""
    @State private var recentFiles: [URL] = []
    @State private var searchResults: [URL] = []
    @Binding var isPresented: Bool
    let onSelect: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(NordTheme.Semantic.textMuted)
                
                TextField("Search files...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(NordTheme.Semantic.textPrimary)
                    .onSubmit {
                        performSearch()
                    }
                
                Text("⌘⇧A")
                    .font(.caption.monospaced())
                    .foregroundColor(NordTheme.Semantic.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NordTheme.Semantic.backgroundTertiary)
                    .cornerRadius(4)
            }
            .padding()
            .background(NordTheme.Semantic.backgroundSecondary)
            
            Divider()
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    if searchQuery.isEmpty {
                        Text("Recent Files")
                            .font(.caption)
                            .foregroundColor(NordTheme.Semantic.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        
                        ForEach(recentFiles, id: \.self) { url in
                            FileResultRow(url: url, onSelect: { selectFile(url) })
                        }
                    } else {
                        ForEach(searchResults, id: \.self) { url in
                            FileResultRow(url: url, onSelect: { selectFile(url) })
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 500)
        .background(NordTheme.Semantic.background)
        .cornerRadius(12)
        .shadow(color: NordTheme.Semantic.shadow, radius: 20)
        .onAppear {
            loadRecentFiles()
        }
    }
    
    private func loadRecentFiles() {
        // Load recent files from user defaults or file system
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if let url = downloadsURL {
            let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey])
            recentFiles = files?.prefix(10).map { $0 } ?? []
        }
    }
    
    private func performSearch() {
        // Fuzzy search implementation
        guard !searchQuery.isEmpty else {
            searchResults = recentFiles
            return
        }
        
        // Simple fuzzy matching
        searchResults = recentFiles.filter { url in
            let filename = url.lastPathComponent.lowercased()
            let query = searchQuery.lowercased()
            return fuzzyMatch(filename, query)
        }
    }
    
    private func fuzzyMatch(_ string: String, _ pattern: String) -> Bool {
        var stringIndex = string.startIndex
        var patternIndex = pattern.startIndex
        
        while stringIndex < string.endIndex && patternIndex < pattern.endIndex {
            if string[stringIndex] == pattern[patternIndex] {
                patternIndex = pattern.index(after: patternIndex)
            }
            stringIndex = string.index(after: stringIndex)
        }
        
        return patternIndex == pattern.endIndex
    }
    
    private func selectFile(_ url: URL) {
        onSelect(url)
        isPresented = false
    }
}

struct FileResultRow: View {
    let url: URL
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: iconForFile(url))
                    .foregroundColor(NordTheme.Semantic.attachment)
                    .frame(width: 24)
                
                VStack(alignment: .leading) {
                    Text(url.lastPathComponent)
                        .foregroundColor(NordTheme.Semantic.textPrimary)
                    
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(NordTheme.Semantic.textMuted)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isHovered ? NordTheme.Semantic.selection : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private func iconForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo"
        case "mp4", "mov", "avi":
            return "film"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.split.3x1"
        case "zip", "rar", "7z":
            return "archivebox"
        default:
            return "doc"
        }
    }
}
