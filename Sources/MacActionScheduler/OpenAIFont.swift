import AppKit
import CoreText
import SwiftUI

@MainActor
enum OpenAIFont {

    enum Face: String, CaseIterable {
        case light = "Light"
        case regular = "Regular"
        case medium = "Medium"
        case semibold = "Semibold"
        case bold = "Bold"

        case lightItalic = "LightItalic"
        case regularItalic = "RegularItalic"
        case mediumItalic = "MediumItalic"
        case semiboldItalic = "SemiboldItalic"
        case boldItalic = "BoldItalic"
    }

    private static var registeredNames: [Face: String] = [:]

    static func register() {
        for face in Face.allCases {
            let filename = "OpenAISans-\(face.rawValue)"

            let url = ["ttf", "otf"].compactMap { ext in
                Bundle.module.url(
                    forResource: filename,
                    withExtension: ext,
                    subdirectory: "Fonts"
                )
            }.first

            guard let url else {
                print("FONT MISSING: \(filename)")
                continue
            }

            _ = CTFontManagerRegisterFontsForURL(
                url as CFURL,
                .process,
                nil
            )

            guard let descriptors =
                    CTFontManagerCreateFontDescriptorsFromURL(
                        url as CFURL
                    ) as? [CTFontDescriptor],
                  let descriptor = descriptors.first,
                  let name = CTFontDescriptorCopyAttribute(
                    descriptor,
                    kCTFontNameAttribute
                  ) as? String
            else {
                print("FONT REGISTRATION FAILED: \(filename)")
                continue
            }

            registeredNames[face] = name
            print("FONT READY: \(filename) -> \(name)")
        }

        print(
            "OpenAI Sans: \(registeredNames.count)/\(Face.allCases.count) fonts loaded."
        )
    }

    static func font(
        _ face: Face,
        size: CGFloat
    ) -> Font {
        if let name = registeredNames[face] {
            return .custom(name, size: size)
        }

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

        let fallback = Font.system(
            size: size,
            weight: weight
        )

        return face.rawValue.hasSuffix("Italic")
            ? fallback.italic()
            : fallback
    }
}
