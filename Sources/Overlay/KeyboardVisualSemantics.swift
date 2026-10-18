import Foundation


enum KeyboardVisualSemantics {
    enum GlyphScale: Equatable {
        case single
        case compact
    }

    static func modifierGlyph(_ modifier: String) -> String? {
        switch modifier {
        case "command": return "⌘"
        case "shift": return "⇧"
        case "option": return "⌥"
        case "control": return "⌃"
        default: return nil
        }
    }

    static func glyphScale(_ token: String) -> GlyphScale {
        token.count == 1 ? .single : .compact
    }
}
