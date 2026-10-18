import SwiftUI


/// Glyph chip the registry cells pin into a key corner. Every call site shares
/// the same scaffold — glyph, inner padding, filled shape, outline, outer
/// inset — and differs only in the appearance and the glyph metrics.
@available(macOS 14, *)
struct ModifierChip<ChipShape: Shape>: View {
    let glyph: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    /// Thumb cells with a physical ID line have no room for the full insets.
    let compact: Bool
    let appearance: ModifierChipAppearance
    let shape: ChipShape

    var body: some View {
        Text(glyph)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(appearance.foreground)
            .padding(.horizontal, compact ? 1 : 4)
            .padding(.vertical, compact ? 0.25 : 1)
            .background(shape.fill(appearance.fill))
            .overlay(
                shape.stroke(appearance.stroke, lineWidth: appearance.strokeWidth)
            )
            .padding(compact ? 1 : 5)
    }
}


struct ModifierChipAppearance {
    let foreground: Color
    let fill: Color
    let stroke: Color
    let strokeWidth: CGFloat

    /// Hold glyph on an ordinary layer: neutral text in a dim shell.
    static let hold = ModifierChipAppearance(
        foreground: Palette.text,
        fill: Palette.base.opacity(0.9),
        stroke: Palette.overlay1,
        strokeWidth: 1
    )

    /// Hold glyph on the Yabai layer: the accent fills the chip while held and
    /// outlines it otherwise.
    static func yabaiHold(
        accentHex: String?,
        isActive: Bool
    ) -> ModifierChipAppearance {
        let accent = accentHex.map(Color.init(hex:))
        let glyphAccent = accent ?? Palette.text
        let outlineAccent = accent ?? Palette.overlay1
        return ModifierChipAppearance(
            foreground: isActive ? Palette.base : glyphAccent,
            fill: isActive ? glyphAccent.opacity(0.92) : Palette.base.opacity(0.9),
            stroke: outlineAccent.opacity(isActive ? 1 : 0.72),
            strokeWidth: isActive ? 2 : 1
        )
    }

    /// Yabai action modifier: the role accent on a dark disc.
    static func yabaiAction(accentHex: String) -> ModifierChipAppearance {
        let accent = Color(hex: accentHex)
        return ModifierChipAppearance(
            foreground: accent,
            fill: Palette.base.opacity(0.92),
            stroke: accent.opacity(0.9),
            strokeWidth: 1
        )
    }
}
