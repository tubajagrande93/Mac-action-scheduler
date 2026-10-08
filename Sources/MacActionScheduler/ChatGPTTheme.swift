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

    static func window(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "212121") : Color.white
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2A2A2A") : Color.white
    }

    static func softField(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2F2F2F") : Color(hex: "F4F4F5")
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "E5E7EB")
    }

    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "343434") : Color(hex: "E5E7EB")
    }

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "F5F5F5") : Color(hex: "111827")
    }

    static func muted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "A1A1AA") : Color(hex: "6B7280")
    }

    static func primaryFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(hex: "171717")
    }

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black : Color.white
    }

    static func secondaryFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2F2F2F") : Color(hex: "F4F4F5")
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(hex: "111827")
    }

    static func selectedPillFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color(hex: "171717")
    }

    static func selectedPillText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black : Color.white
    }
}
