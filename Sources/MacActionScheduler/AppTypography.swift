import SwiftUI

/// Typography backed exclusively by the macOS system font (San Francisco).
/// No third-party font assets, CoreText registration, or redistribution.
enum AppTypography {
    enum Face {
        case light
        case regular
        case medium
        case semibold
        case bold
        case lightItalic
        case regularItalic
        case mediumItalic
        case semiboldItalic
        case boldItalic
    }

    static func font(_ face: Face, size: CGFloat) -> Font {
        let weight: Font.Weight

        switch face {
        case .light, .lightItalic:
            weight = .light
        case .regular, .regularItalic:
            weight = .regular
        case .medium, .mediumItalic:
            weight = .medium
        case .semibold, .semiboldItalic:
            weight = .semibold
        case .bold, .boldItalic:
            weight = .bold
        }

        let font = Font.system(size: size, weight: weight, design: .default)
        switch face {
        case .lightItalic, .regularItalic, .mediumItalic,
             .semiboldItalic, .boldItalic:
            return font.italic()
        default:
            return font
        }
    }
}
