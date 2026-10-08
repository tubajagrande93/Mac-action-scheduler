import SwiftUI

/// Typography backed exclusively by the macOS system font (San Francisco).
/// No third-party font assets, CoreText registration, or redistribution.
enum AppTypography {
    enum Face {
        case regular
        case medium
        case semibold
    }

    static func font(_ face: Face, size: CGFloat) -> Font {
        let weight: Font.Weight

        switch face {
        case .regular:
            weight = .regular
        case .medium:
            weight = .medium
        case .semibold:
            weight = .semibold
        }

        return Font.system(size: size, weight: weight, design: .default)
    }
}
