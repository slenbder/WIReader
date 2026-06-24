import SwiftUI
import UIKit

struct ReaderTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let backgroundHex: String
    let textHex: String
    let secondaryTextHex: String
    let isPremium: Bool

    var backgroundColor: Color { Color(hex: backgroundHex) }
    var textColor: Color { Color(hex: textHex) }
    var secondaryTextColor: Color { Color(hex: secondaryTextHex) }

    var uiBackgroundColor: UIColor { UIColor(hex: backgroundHex) }
    var uiTextColor: UIColor { UIColor(hex: textHex) }
    var uiSecondaryTextColor: UIColor { UIColor(hex: secondaryTextHex) }

    var cssOverride: String {
        """
        html, body {
            background: \(backgroundHex) !important;
            color: \(textHex) !important;
        }
        body, p, div, span, section, article, main, li {
            color: \(textHex) !important;
        }
        h1, h2, h3, h4, h5, h6 {
            color: \(textHex) !important;
        }
        a {
            color: \(secondaryTextHex) !important;
        }
        """
    }

    static let light = ReaderTheme(
        id: "light",
        name: "Light",
        backgroundHex: "#FFFFFF",
        textHex: "#111111",
        secondaryTextHex: "#5B6472",
        isPremium: false
    )

    static let dark = ReaderTheme(
        id: "dark",
        name: "Dark",
        backgroundHex: "#111111",
        textHex: "#F2F2F2",
        secondaryTextHex: "#B8C0CC",
        isPremium: false
    )

    static let sepia = ReaderTheme(
        id: "sepia",
        name: "Sepia",
        backgroundHex: "#F4ECD8",
        textHex: "#2D2418",
        secondaryTextHex: "#7A6243",
        isPremium: false
    )

    static let midnight = ReaderTheme(
        id: "midnight",
        name: "Midnight",
        backgroundHex: "#08111F",
        textHex: "#EAF1FF",
        secondaryTextHex: "#8FB4FF",
        isPremium: true
    )

    static let forest = ReaderTheme(
        id: "forest",
        name: "Forest",
        backgroundHex: "#101A14",
        textHex: "#EEF5EA",
        secondaryTextHex: "#9FCA9E",
        isPremium: true
    )

    static let all: [ReaderTheme] = [.light, .dark, .sepia, .midnight, .forest]

    static func theme(for id: String) -> ReaderTheme {
        all.first { $0.id == id } ?? .light
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
