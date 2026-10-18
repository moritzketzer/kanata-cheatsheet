import SwiftUI


@available(macOS 14, *)
struct KeyCell: View {
    let key: KeyboardPresentedKey
    let source: KeyboardPresentationSource
    let width: CGFloat
    let height: CGFloat
    var physicalId: String? = nil
    var showsShell: Bool = true
    var uniformThumbLayout: Bool = false

    @Environment(\.isYabaiLayer) private var isYabaiLayer

    private var isOccupied: Bool {
        if source == .registry {
            return key.primary != nil || key.keyLabel != nil
        }
        return key.actionLabel != nil || key.keyLabel != nil
    }

    private var color: Color {
        key.colorHex.map(Color.init(hex:)) ?? Palette.text
    }

    var fillColor: Color {
        isOccupied ? color.opacity(0.12) : Palette.surface0.opacity(0.28)
    }

    var strokeColor: Color {
        isOccupied ? color.opacity(0.24) : Palette.text.opacity(0.06)
    }

    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 6).fill(showsShell ? fillColor : .clear))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(showsShell ? strokeColor : .clear, lineWidth: 1))
    }

    /// Text in a thumb cell shares its height with the physical ID line, so it
    /// needs a readable floor instead of the plain height factor.
    private func cellFontSize(_ factor: CGFloat, floor: CGFloat = 3.5) -> CGFloat {
        physicalId == nil ? height * factor : max(floor, height * factor)
    }

    @ViewBuilder
    private var content: some View {
        if let physicalId {
            VStack(spacing: 1) {
                Text(physicalId)
                    .font(.system(size: max(6, height * 0.15), weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.subtext0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                actionContent
            }
            .frame(width: width, height: height)
        } else {
            ordinaryContent
        }
    }

    private var ordinaryContent: some View {
        ZStack(alignment: .topLeading) {
            if let badge = key.badge {
                Text(badge)
                    .font(.system(
                        size: height * 0.15,
                        weight: .semibold,
                        design: .monospaced
                    ))
                    .foregroundStyle(
                        isOccupied
                            ? Palette.subtext0
                            : Palette.surface2
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(5)
            }

            actionContent
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private var actionContent: some View {
        if source == .registry {
            registryContent
        } else {
            legacyContent
        }
    }

    @ViewBuilder
    private var registryContent: some View {
        if isYabaiLayer {
            yabaiRegistryContent
        } else {
            standardRegistryContent
        }
    }

    private var standardRegistryContent: some View {
        registryCellBody(
            stackSpacing: physicalId == nil ? 3 : 1,
            explanation: ExplanationStyle(
                foreground: Palette.subtext1,
                lineLimit: 1,
                alignment: .leading,
                height: nil
            ),
            trailingPadding: 0,
            bottomSpacerLength: physicalId == nil ? 5 : 0
        ) {
            if let modifier = key.holdModifier,
               let glyph = KeyboardVisualSemantics.modifierGlyph(modifier)
            {
                ModifierChip(
                    glyph: glyph,
                    fontSize: height * 0.15,
                    fontWeight: .semibold,
                    compact: false,
                    appearance: .hold,
                    shape: RoundedRectangle(cornerRadius: 4)
                )
            }
        }
    }

    /// Only reached inside the Yabai layer, so the action and hold chips are
    /// always the Yabai variants.
    private var yabaiRegistryContent: some View {
        registryCellBody(
            stackSpacing: physicalId == nil ? 3 : 0,
            explanation: ExplanationStyle(
                foreground: key.actionModifier == nil ? Palette.subtext1 : color,
                lineLimit: physicalId == nil ? 2 : 1,
                alignment: .center,
                height: height * 0.24
            ),
            trailingPadding: physicalId != nil
                && (key.actionModifier != nil || key.holdModifier != nil) ? 7 : 0,
            bottomSpacerLength: physicalId != nil
                ? 0
                : (key.holdModifier != nil ? height * 0.26 : 5)
        ) {
            if let actionModifier = key.actionModifier {
                ModifierChip(
                    glyph: actionModifier.glyph,
                    fontSize: cellFontSize(0.12),
                    fontWeight: .bold,
                    compact: physicalId != nil,
                    appearance: .yabaiAction(accentHex: actionModifier.accentHex),
                    shape: Circle()
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )
            }

            if let modifier = key.holdModifier,
               let glyph = KeyboardVisualSemantics.modifierGlyph(modifier)
            {
                ModifierChip(
                    glyph: glyph,
                    fontSize: cellFontSize(0.15),
                    fontWeight: .semibold,
                    compact: physicalId != nil,
                    appearance: .yabaiHold(
                        accentHex: key.holdAccentHex,
                        isActive: key.isHoldActive
                    ),
                    shape: RoundedRectangle(cornerRadius: 4)
                )
            }
        }
    }

    /// Primary glyph stack with its explanation or free label, plus the
    /// caller's modifier chips pinned to the bottom trailing corner.
    private func registryCellBody<Chips: View>(
        stackSpacing: CGFloat,
        explanation: ExplanationStyle,
        trailingPadding: CGFloat,
        bottomSpacerLength: CGFloat,
        @ViewBuilder chips: () -> Chips
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: stackSpacing) {
                Spacer(minLength: physicalId == nil ? 5 : 0)
                primaryContent
                    .frame(height: uniformThumbLayout ? height * 0.38 : nil)
                if let text = key.explanation {
                    Text(text)
                        .font(.system(size: cellFontSize(0.12), weight: .medium))
                        .foregroundStyle(explanation.foreground)
                        .lineLimit(explanation.lineLimit)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(explanation.alignment)
                        .frame(height: explanation.height)
                } else if let freeLabel = key.freeLabel {
                    Text(freeLabel)
                        .font(.system(size: height * 0.13, design: .monospaced))
                        .foregroundStyle(Palette.surface2)
                }
                Spacer(minLength: bottomSpacerLength)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, physicalId == nil ? 4 : 1)
            .padding(.trailing, trailingPadding)

            chips()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var primaryContent: some View {
        if let keyLabel = key.keyLabel {
            Text(keyLabel)
                .font(.system(
                    size: height * 0.28,
                    weight: .semibold,
                    design: .monospaced
                ))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        } else if let primary = key.primary {
            if primary.kind == "glyph" {
                let scale = KeyboardVisualSemantics.glyphScale(primary.token)
                Text(primary.token)
                    .font(.system(
                        size: cellFontSize(
                            scale == .single ? 0.38 : 0.28,
                            floor: 8
                        ),
                        weight: .semibold,
                        design: .monospaced
                    ))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                RegistryIcon(
                    icon: RegistryKeyIcon(kind: primary.kind, token: primary.token),
                    size: cellFontSize(0.34, floor: 8)
                )
                .foregroundStyle(color)
            }
        }
    }

    private var legacyContent: some View {
        VStack(spacing: 1) {
            Text(key.badge ?? "")
                .font(.system(
                    size: height * (isOccupied ? 0.27 : 0.23),
                    weight: isOccupied ? .bold : .regular,
                    design: .monospaced
                ))
                .foregroundStyle(
                    isOccupied ? color : Palette.surface1
                )
            if let actionLabel = key.actionLabel {
                Text(actionLabel)
                    .font(.system(size: height * 0.18, design: .monospaced))
                    .foregroundStyle(Palette.subtext1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


/// Styling the two registry cell flavors give their explanation line.
private struct ExplanationStyle {
    let foreground: Color
    let lineLimit: Int
    let alignment: TextAlignment
    let height: CGFloat?
}


@available(macOS 14, *)
private struct RegistryIcon: View {
    let icon: RegistryKeyIcon
    let size: CGFloat

    var body: some View {
        Group {
            if icon.kind == "app-font" {
                Text(icon.token)
                    .font(.custom("sketchybar-app-font", size: size))
                    .lineLimit(1)
            } else {
                Image(systemName: icon.token)
                    .font(.system(size: size, weight: .medium))
            }
        }
        .offset(
            x: RegistryIconLayout.horizontalCorrection(for: icon, size: size)
        )
        .opacity(RegistryIconLayout.opacity)
    }
}
