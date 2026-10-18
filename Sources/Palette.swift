import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        switch cleaned.count {
        case 6:
            red = Double((int >> 16) & 0xFF) / 255
            green = Double((int >> 8) & 0xFF) / 255
            blue = Double(int & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((int >> 24) & 0xFF) / 255
            green = Double((int >> 16) & 0xFF) / 255
            blue = Double((int >> 8) & 0xFF) / 255
            alpha = Double(int & 0xFF) / 255
        default:
            red = 1
            green = 0
            blue = 1
            alpha = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// Catppuccin Mocha palette used across the overlay and browser views.
/// Standard roles keep their upstream names; the two bespoke values are
/// named by their single role in the input-path header.
enum Palette {
    static let base = Color(hex: "#1e1e2e")
    static let surface0 = Color(hex: "#313244")
    static let surface1 = Color(hex: "#45475a")
    static let surface2 = Color(hex: "#585b70")
    static let overlay0 = Color(hex: "#6c7086")
    static let overlay1 = Color(hex: "#7f849c")
    static let subtext0 = Color(hex: "#a6adc8")
    static let subtext1 = Color(hex: "#bac2de")
    static let text = Color(hex: "#cdd6f4")
    static let mauve = Color(hex: "#cba6f7")
    static let inputPathArrow = Color(hex: "#9696aa")
    static let inputPathTitle = Color(hex: "#e4e4ed")
}
