import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 8:
            (a, r, g, b) = (
                (int >> 24) & 0xff,
                (int >> 16) & 0xff,
                (int >> 8) & 0xff,
                int & 0xff
            )
        default:
            (a, r, g, b) = (
                255,
                (int >> 16) & 0xff,
                (int >> 8) & 0xff,
                int & 0xff
            )
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum ChatGPTTheme {
    static func page(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "212121") : Color(hex: "F7F7F8")
    }

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(hex: "0F172A")
    }

    static func muted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "A1A1AA") : Color(hex: "6B7280")
    }

    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "343434") : Color(hex: "E5E7EB")
    }

    // Samo glavni CTA/status surface
    static func actionSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(hex: "E7E7EA")
    }

    static func actionText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black : Color(hex: "111827")
    }

    static func disabledSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2C2C2C") : Color(hex: "F0F0F2")
    }

    static func disabledText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "777777") : Color(hex: "9CA3AF")
    }

    static func selectedText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color.black
    }

    static func selectedUnderline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color.black
    }
}
