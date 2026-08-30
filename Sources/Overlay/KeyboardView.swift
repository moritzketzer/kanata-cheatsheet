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


@available(macOS 14, *)
struct KeyboardView: View {
    let presentation: KeyboardLayerPresentation
    let config: Config.Display
    let registry: KeybindingRegistry?
    let showFreeModifierSpace: Bool

    let keySize: CGFloat
    let contentWidth: CGFloat
    static let keySpacing: CGFloat = 4

    init(
        layerName: String,
        legacyLayer: Config.Layer?,
        display: Config.Display,
        registry: KeybindingRegistry? = nil,
        showFreeModifierSpace: Bool = false
    ) {
        let presentation = KeyboardLayerProjector.presentation(
            layerName: layerName,
            legacyLayer: legacyLayer,
            registry: registry,
            showFree: showFreeModifierSpace
        ) ?? KeyboardLayerPresentation(
            name: layerName,
            label: layerName,
            trigger: "manual",
            source: .legacy,
            rows: [],
            groups: []
        )
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        let targetWidth = screenWidth * CGFloat(display.width_percent) / 100
        let maxRowUnits = presentation.rows.map { row in
            row.map(\.width).reduce(0, +)
        }.max() ?? 14
        let maxKeyCount = presentation.rows.map(\.count).max() ?? 1
        let horizontalPadding: CGFloat = 64
        let gaps = CGFloat(max(0, maxKeyCount - 1)) * Self.keySpacing

        self.presentation = presentation
        self.config = display
        self.registry = registry
        self.showFreeModifierSpace = showFreeModifierSpace
        self.keySize = max(28, (targetWidth - horizontalPadding - gaps) / maxRowUnits)
        self.contentWidth = targetWidth - horizontalPadding
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(presentation.label)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#cba6f7"))
                .tracking(4)
                .textCase(.uppercase)

            VStack(spacing: Self.keySpacing) {
                ForEach(Array(presentation.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Self.keySpacing) {
                        ForEach(row) { key in
                            KeyCell(
                                key: key,
                                source: presentation.source,
                                width: CGFloat(key.width) * keySize,
                                height: keySize
                            )
                        }
                    }
                }

                if let cluster = presentation.arrowCluster {
                    HStack {
                        Spacer(minLength: 0)
                        arrowBlock(cluster)
                    }
                    .frame(width: contentWidth)
                }
            }

            if let thumbs = presentation.defyThumbs {
                VStack(spacing: 6) {
                    Text(thumbs.label)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#6c7086"))
                        .tracking(2)
                        .textCase(.uppercase)

                    HStack(alignment: .bottom, spacing: keySize * 1.25) {
                        defyHalf(
                            top: thumbs.leftTop,
                            bottom: thumbs.leftBottom,
                            topOffset: keySize * 0.18
                        )
                        defyHalf(
                            top: thumbs.rightTop,
                            bottom: thumbs.rightBottom,
                            topOffset: -keySize * 0.18
                        )
                    }
                }
            }

            if presentation.hasHoldModifiers {
                Text("KEY ↖   TAP ●   HOLD ↘")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#6c7086"))
                    .tracking(1.2)
            }

            if !presentation.groups.isEmpty {
                HStack(spacing: 24) {
                    ForEach(presentation.groups) { group in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: group.colorHex))
                                .frame(width: 8, height: 8)
                            Text(group.id)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#6c7086"))
                        }
                    }
                }
                .padding(.top, 4)
            }

            if let footer = presentation.footer {
                Divider()
                    .overlay(Color(hex: "#45475a"))
                LayerFooterView(footer: footer, availableWidth: contentWidth)
            }

            if presentation.name == "apps", let registry {
                Divider()
                    .overlay(Color(hex: "#45475a"))
                ModifierSpaceLegend(
                    slots: registry.views.modifierSpace.slots,
                    registry: registry,
                    showFree: showFreeModifierSpace,
                    availableWidth: contentWidth
                )
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: CGFloat(config.corner_radius))
                .fill(Color(hex: config.background_color))
        )
        .fixedSize()
    }

    private func defyHalf(
        top: [KeyboardPresentedKey],
        bottom: [KeyboardPresentedKey],
        topOffset: CGFloat
    ) -> some View {
        let thumbWidth = keySize * 0.88
        let thumbHeight = keySize * 0.72
        return VStack(spacing: Self.keySpacing) {
            HStack(spacing: Self.keySpacing) {
                ForEach(top) { key in
                    KeyCell(
                        key: key,
                        source: presentation.source,
                        width: CGFloat(key.width) * thumbWidth,
                        height: thumbHeight
                    )
                }
            }
            .offset(x: topOffset)

            HStack(spacing: Self.keySpacing) {
                ForEach(bottom) { key in
                    KeyCell(
                        key: key,
                        source: presentation.source,
                        width: CGFloat(key.width) * thumbWidth,
                        height: thumbHeight
                    )
                }
            }
        }
    }

    private func arrowBlock(_ cluster: KeyboardPresentedArrowCluster) -> some View {
        Grid(
            horizontalSpacing: Self.keySpacing,
            verticalSpacing: Self.keySpacing
        ) {
            GridRow {
                Color.clear.frame(width: keySize, height: keySize)
                KeyCell(
                    key: cluster.up,
                    source: presentation.source,
                    width: keySize,
                    height: keySize
                )
                Color.clear.frame(width: keySize, height: keySize)
            }
            GridRow {
                ForEach([cluster.left, cluster.down, cluster.right]) { key in
                    KeyCell(
                        key: key,
                        source: presentation.source,
                        width: keySize,
                        height: keySize
                    )
                }
            }
        }
    }
}


@available(macOS 14, *)
struct KeyCell: View {
    let key: KeyboardPresentedKey
    let source: KeyboardPresentationSource
    let width: CGFloat
    let height: CGFloat

    private var isOccupied: Bool {
        if source == .registry {
            return key.primary != nil || key.keyLabel != nil
        }
        return key.actionLabel != nil || key.keyLabel != nil
    }

    private var color: Color {
        key.colorHex.map(Color.init(hex:)) ?? Color(hex: "#cdd6f4")
    }

    var body: some View {
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
                            ? Color(hex: "#a6adc8")
                            : Color(hex: "#585b70")
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(5)
            }

            if source == .registry {
                registryContent
            } else {
                legacyContent
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isOccupied
                        ? color.opacity(0.12)
                        : Color(hex: "#313244").opacity(0.28)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isOccupied
                        ? color.opacity(0.24)
                        : Color(hex: "#cdd6f4").opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private var registryContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 3) {
                Spacer(minLength: 5)
                primaryContent
                if let explanation = key.explanation {
                    Text(explanation)
                        .font(.system(size: height * 0.12, weight: .medium))
                        .foregroundStyle(Color(hex: "#bac2de"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else if let freeLabel = key.freeLabel {
                    Text(freeLabel)
                        .font(.system(size: height * 0.13, design: .monospaced))
                        .foregroundStyle(Color(hex: "#585b70"))
                }
                Spacer(minLength: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)

            if let modifier = key.holdModifier,
               let glyph = KeyboardVisualSemantics.modifierGlyph(modifier)
            {
                Text(glyph)
                    .font(.system(size: height * 0.15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#cdd6f4"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#1e1e2e").opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(hex: "#7f849c"), lineWidth: 1)
                    )
                    .padding(5)
            }
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
                        size: height * (scale == .single ? 0.38 : 0.28),
                        weight: .semibold,
                        design: .monospaced
                    ))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                RegistryIcon(
                    icon: RegistryKeyIcon(kind: primary.kind, token: primary.token),
                    size: height * 0.34
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
                    isOccupied ? color : Color(hex: "#45475a")
                )
            if let actionLabel = key.actionLabel {
                Text(actionLabel)
                    .font(.system(size: height * 0.18, design: .monospaced))
                    .foregroundStyle(Color(hex: "#bac2de"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
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
