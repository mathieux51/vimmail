# VimMail

A native macOS email client with vim-style navigation, Nord theme, and Claude AI integration.

## Features

### Vim-like Navigation
- **Normal Mode**: Navigate with `j`/`k`, actions with single keys
- **Insert Mode**: Type and compose emails
- **Visual Mode**: Multi-select emails with `v`
- **Command Mode**: Execute commands with `:`
- **Search Mode**: Quick search with `/`

### Key Shortcuts

| Key | Action |
|-----|--------|
| `j/k` | Move down/up |
| `gg/G` | Go to top/bottom |
| `Enter` | Open email |
| `r/R` | Reply/Reply all |
| `f` | Forward |
| `c` | Compose new |
| `a` | Archive |
| `dd` | Delete |
| `s` | Toggle star |
| `u` | Mark unread |
| `e` | Report spam |
| `x` | Select/deselect |
| `v` | Visual mode |
| `i` | Insert mode |
| `:` | Command mode |
| `/` | Search |
| `?` | Show shortcuts |
| `t` | Toggle preview theme |
| `Cmd+/-` | Zoom in/out |
| `1-9` | Switch accounts |

### Claude AI Integration
- **Reply Suggestions**: Press `AI Suggest` in compose to get reply options
- **Autocomplete**: `Ctrl+Space` for AI-powered text completion
- **Email Summarization**: Quick summaries of long threads
- **Phishing Detection**: AI-assisted security analysis

### Security Features
- **Sender Verification**: SPF/DKIM status badges
- **Phishing Warnings**: Visual alerts for suspicious emails
- **Always-visible sender email**: Full email address always shown

### Email Preview
- **Dark/Light modes**: Toggle with `t`
- **Zoom control**: `Cmd+/Cmd-` without changing email font
- **HTML rendering**: Full HTML email support

### Multiple Accounts
- Connect multiple Google accounts
- Quick switch with number keys `1-9`
- Per-account folder organization

### Email Filters
- Filter by sender (regex supported)
- Filter by subject (regex supported)
- Filter by body content
- Auto-actions: move, label, delete, etc.

### Fast Search
- SQLite FTS5 for sub-millisecond search
- Handles 100k+ emails efficiently
- Search across subject, body, sender

### Attachments
- Fuzzy file search for attaching (`Cmd+Shift+A`)
- Quick preview with `o`
- Visual attachment cards

### Desktop Notifications
- New email alerts
- Quick actions from notification
- Badge count on dock icon

## Requirements

- macOS 14.0+
- Google Account for Gmail
- Claude API key for AI features

## Setup

1. Clone the repository
2. Open in Xcode or build with Swift Package Manager
3. Add your Google OAuth credentials in `GoogleOAuthConfig`
4. Add your Claude API key in Settings

```bash
cd vimmail
swift build
swift run VimMail
```

## Configuration

### Google OAuth Setup
1. Create a project in Google Cloud Console
2. Enable Gmail API
3. Create OAuth 2.0 credentials
4. Add redirect URI: `com.vimmail://oauth2callback`
5. Update `GoogleOAuthConfig.clientId`

### Claude API Setup
1. Get an API key from [Anthropic Console](https://console.anthropic.com)
2. Add key in VimMail Settings > AI

## Architecture

```
Sources/VimMail/
├── App/              # App entry, state management
├── Models/           # Email, Account, Filter models
├── Views/            # SwiftUI views
├── ViewModels/       # View logic
├── Services/         # Gmail API, Claude API, Database
├── Theme/            # Nord color theme
└── Utilities/        # Keyboard handler, helpers
```

## License

MIT
