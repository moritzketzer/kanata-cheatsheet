import SwiftUI


@available(macOS 14, *)
struct YabaiModifierLegend: View {
    let activeModifiers: Set<YabaiModifier>

    private let roles: [YabaiModifier] = [
        .option, .shift, .command, .control,
    ]

    var body: some View {
        HStack(spacing: 7) {
            Text("HOLD")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.overlay0)
                .tracking(1)

            ForEach(roles, id: \.self) { modifier in
                legendChip(for: modifier)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// One role's capsule. Holding the modifier fills and outlines it in that
    /// role's accent instead of leaving it a dim outline.
    private func legendChip(for modifier: YabaiModifier) -> some View {
        let isActive = activeModifiers.contains(modifier)
        return HStack(spacing: 4) {
            Text(modifier.glyph)
                .font(.system(size: 11, weight: .bold))
            Text(modifier.roleLabel)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(Color(hex: modifier.accentHex))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    isActive
                        ? Color(hex: modifier.accentHex).opacity(0.22)
                        : Palette.base.opacity(0.72)
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    Color(hex: modifier.accentHex)
                        .opacity(isActive ? 0.95 : 0.42),
                    lineWidth: isActive ? 1.5 : 1
                )
        )
    }
}
