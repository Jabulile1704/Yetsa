import SwiftUI

extension Color {
    nonisolated init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// Windows are coloured by where they sit in the day, so the timeline reads as
/// a sunrise-to-dark gradient rather than a list of identical cards.
enum Palette {
    static func window(_ kind: WindowKind, _ scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch kind {
        case .morning:
            return Color(hex: dark ? "E89A42" : "D1792A")
        case .commuteOut:
            return Color(hex: dark ? "6E93C4" : "4C74A6")
        case .workMorning, .workAfternoon:
            return Color(hex: dark ? "8A98A8" : "66768A")
        case .lunch:
            return Color(hex: dark ? "57A877" : "357F52")
        case .commuteHome:
            return Color(hex: dark ? "9184C4" : "6E5FA3")
        case .evening:
            return Color(hex: dark ? "6C7FC4" : "4A5BA3")
        case .afternoon:
            return Color(hex: dark ? "E0B050" : "C3912F")
        }
    }

    /// Green when the plan fits, amber when it is tight, red when it does not.
    static func load(_ fraction: Double, _ scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        if fraction > 1.0 { return Color(hex: dark ? "E3715F" : "C44A36") }
        if fraction > 0.8 { return Color(hex: dark ? "E0A845" : "BC8420") }
        return Color(hex: dark ? "5FB07E" : "398057")
    }

    static func anchorTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "9AA3AD") : Color(hex: "7A838D")
    }
}
