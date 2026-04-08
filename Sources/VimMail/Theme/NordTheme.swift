import SwiftUI

// MARK: - Nord Theme Colors
// Based on https://www.nordtheme.com/docs/colors-and-palettes

struct NordTheme {
    // Polar Night - Dark backgrounds
    static let nord0 = Color(hex: "#2E3440")  // Darkest background
    static let nord1 = Color(hex: "#3B4252")  // Lighter background
    static let nord2 = Color(hex: "#434C5E")  // Selection background
    static let nord3 = Color(hex: "#4C566A")  // Comments, subtle
    
    // Snow Storm - Light text/elements
    static let nord4 = Color(hex: "#D8DEE9")  // Primary text
    static let nord5 = Color(hex: "#E5E9F0")  // Secondary text
    static let nord6 = Color(hex: "#ECEFF4")  // Bright text/highlights
    
    // Frost - Blue accents
    static let nord7 = Color(hex: "#8FBCBB")   // Teal, classes
    static let nord8 = Color(hex: "#88C0D0")   // Cyan, declarations
    static let nord9 = Color(hex: "#81A1C1")   // Blue, keywords
    static let nord10 = Color(hex: "#5E81AC")  // Dark blue, functions
    
    // Aurora - Accent colors
    static let nord11 = Color(hex: "#BF616A")  // Red, errors
    static let nord12 = Color(hex: "#D08770")  // Orange, warnings
    static let nord13 = Color(hex: "#EBCB8B")  // Yellow, strings
    static let nord14 = Color(hex: "#A3BE8C")  // Green, success
    static let nord15 = Color(hex: "#B48EAD")  // Purple, numbers
    
    // Semantic colors
    struct Semantic {
        // Backgrounds
        static let background = nord0
        static let backgroundSecondary = nord1
        static let backgroundTertiary = nord2
        static let selection = nord2
        
        // Text
        static let textPrimary = nord4
        static let textSecondary = nord3
        static let textMuted = nord3
        static let textBright = nord6
        
        // Accents
        static let accent = nord8
        static let accentSecondary = nord9
        static let link = nord8
        
        // Status
        static let success = nord14
        static let warning = nord13
        static let error = nord11
        static let info = nord10
        
        // UI Elements
        static let border = nord3
        static let divider = nord2
        static let shadow = nord0.opacity(0.5)
        
        // Email specific
        static let unread = nord8
        static let starred = nord13
        static let spam = nord11
        static let draft = nord12
        static let sent = nord14
        static let attachment = nord15
        
        // Phishing warning
        static let phishingWarning = nord11
        static let verifiedSender = nord14
        static let unknownSender = nord12
    }
    
    // Light theme variants
    struct Light {
        static let background = nord6
        static let backgroundSecondary = nord5
        static let backgroundTertiary = nord4
        static let selection = nord4.opacity(0.5)
        
        static let textPrimary = nord0
        static let textSecondary = nord2
        static let textMuted = nord3
        static let textBright = nord1
        
        static let border = nord4
        static let divider = nord5
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var hexString: String {
        guard let components = NSColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Theme Environment Key
struct ThemeKey: EnvironmentKey {
    static let defaultValue: Bool = true // true = dark mode
}

extension EnvironmentValues {
    var isDarkMode: Bool {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Theme-aware View Modifier
struct NordBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? NordTheme.Semantic.background : NordTheme.Light.background)
    }
}

struct NordText: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var style: TextStyle = .primary
    
    enum TextStyle {
        case primary, secondary, muted, bright
    }
    
    func body(content: Content) -> some View {
        content.foregroundColor(textColor)
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return colorScheme == .dark ? NordTheme.Semantic.textPrimary : NordTheme.Light.textPrimary
        case .secondary:
            return colorScheme == .dark ? NordTheme.Semantic.textSecondary : NordTheme.Light.textSecondary
        case .muted:
            return colorScheme == .dark ? NordTheme.Semantic.textMuted : NordTheme.Light.textMuted
        case .bright:
            return colorScheme == .dark ? NordTheme.Semantic.textBright : NordTheme.Light.textBright
        }
    }
}

extension View {
    func nordBackground() -> some View {
        modifier(NordBackground())
    }
    
    func nordText(_ style: NordText.TextStyle = .primary) -> some View {
        modifier(NordText(style: style))
    }
}

// MARK: - Button Styles
struct NordButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var variant: Variant = .primary
    
    enum Variant {
        case primary, secondary, danger
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(textColor)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        let base: Color
        switch variant {
        case .primary:
            base = NordTheme.nord10
        case .secondary:
            base = NordTheme.nord2
        case .danger:
            base = NordTheme.nord11
        }
        return isPressed ? base.opacity(0.8) : base
    }
    
    private var textColor: Color {
        switch variant {
        case .primary, .danger:
            return NordTheme.nord6
        case .secondary:
            return NordTheme.nord4
        }
    }
}

// MARK: - Text Field Styles
struct NordTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(10)
            .background(colorScheme == .dark ? NordTheme.nord1 : NordTheme.Light.backgroundSecondary)
            .foregroundColor(colorScheme == .dark ? NordTheme.nord4 : NordTheme.Light.textPrimary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(NordTheme.nord3, lineWidth: 1)
            )
    }
}
