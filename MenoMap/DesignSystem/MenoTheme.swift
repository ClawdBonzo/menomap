import SwiftUI
import UIKit

/// MenoMap design tokens. Source of truth: Docs/MenoMap_Visual_Identity.md.
enum MenoTheme {
    // MARK: Color

    static let ground = dynamic(light: 0xF3EEE7, dark: 0x151311)
    static let surface = dynamic(light: 0xFBF8F4, dark: 0x211E1B)
    static let surfaceRaised = dynamic(light: 0xFFFFFF, dark: 0x2B2724)
    static let ink = dynamic(light: 0x1E2524, dark: 0xF2ECE4)
    static let inkSecondary = dynamic(light: 0x5E6663, dark: 0xB5ADA3)
    static let hairline = dynamic(light: 0x1E2524, dark: 0xF2ECE4, lightAlpha: 0.10, darkAlpha: 0.12)
    static let teal = dynamic(light: 0x0D6B66, dark: 0x52B8AE)
    static let tealSoft = dynamic(light: 0xDCEBE8, dark: 0x1C3431)
    static let ember = dynamic(light: 0xD4552A, dark: 0xF07A4C)
    static let danger = dynamic(light: 0xB3261E, dark: 0xF2B8B5)
    static let dangerSoft = dynamic(light: 0xF9E3E1, dark: 0x3A1F1D)
    /// Text on a teal fill.
    static let onTeal = dynamic(light: 0xFFFFFF, dark: 0x0B1F1D)

    static let nightGround = Color(hex: 0x0B0A09)
    static let nightInk = Color(hex: 0xC9503A)

    /// Ember opacity for heat levels 0…5. Level 0 draws the hairline instead.
    static let heatOpacity: [Double] = [0, 0.14, 0.30, 0.48, 0.70, 0.94]

    static func heat(_ level: Int) -> Color {
        let l = min(max(level, 0), 5)
        return l == 0 ? hairline : ember.opacity(heatOpacity[l])
    }

    /// Text color that stays readable on a heat cell.
    static func onHeat(_ level: Int) -> Color {
        level >= 4 ? .white : ink
    }

    // MARK: Shape & space

    static let radiusCard: CGFloat = 20
    static let radiusButton: CGFloat = 16
    static let space: CGFloat = 8
    static let minHit: CGFloat = 44

    // MARK: Type

    static func headline(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    static func number(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.semibold).monospacedDigit()
    }

    // MARK: Helpers

    private static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
