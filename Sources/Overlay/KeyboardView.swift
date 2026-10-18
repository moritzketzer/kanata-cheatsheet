import SwiftUI


@available(macOS 14, *)
struct KeyboardView: View {
    let presentation: KeyboardLayerPresentation
    let config: Config.Display
    let showInputPath: Bool
    let activeModifiers: Set<YabaiModifier>
    let yabaiQualifier: String?
    let pomodoroStatus: PomodoroStatus?

    let keySize: CGFloat
    let contentWidth: CGFloat
    static let keySpacing: CGFloat = 4

    init(
        layerName: String,
        legacyLayer: Config.Layer?,
        display: Config.Display,
        registry: KeybindingRegistry? = nil,
        showFreeModifierSpace: Bool = false,
        geometryProfileId: String? = nil,
        showInputPath: Bool = false,
        activeModifiers: Set<YabaiModifier> = [],
        yabaiQualifier: String? = nil,
        pomodoroStatus: PomodoroStatus? = nil
    ) {
        let presentation = KeyboardLayerProjector.presentation(
            layerName: layerName,
            legacyLayer: legacyLayer,
            registry: registry,
            showFree: showFreeModifierSpace,
            geometryProfileId: geometryProfileId,
            activeModifiers: activeModifiers
        ) ?? KeyboardLayerPresentation(
            name: layerName,
            label: layerName,
            trigger: Config.Layer.manualTrigger,
            source: .legacy,
            rows: [],
            groups: []
        )
        let contentWidth = KeyboardGeometryMetrics.contentWidth(
            screenWidth: NSScreen.main?.frame.width ?? 1440,
            widthPercent: display.width_percent
        )

        self.presentation = presentation
        self.config = display
        self.showInputPath = showInputPath
        self.activeModifiers = activeModifiers
        self.yabaiQualifier = yabaiQualifier
        self.pomodoroStatus = pomodoroStatus
        self.keySize = KeyboardGeometryMetrics.keySize(
            for: presentation.geometry,
            contentWidth: contentWidth,
            showInputPath: showInputPath,
            spacing: Self.keySpacing
        )
        self.contentWidth = contentWidth
    }

    var body: some View {
        VStack(spacing: 16) {
            headerView

            geometryContent

            holdLegendView

            groupLegendView

            if !showInputPath, let footer = presentation.footer {
                Divider()
                    .overlay(Palette.surface1)
                LayerFooterView(footer: footer, availableWidth: contentWidth)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: CGFloat(config.corner_radius))
                .fill(Color(hex: config.background_color))
        )
        .fixedSize()
    }

    @ViewBuilder
    private var headerView: some View {
        if showInputPath {
            Text("Source")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.inputPathTitle)
        } else if presentation.isYabaiLayer {
            VStack(spacing: 3) {
                LayerTitleText(label: presentation.label)

                Text(yabaiQualifier ?? " ")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.overlay0)
                    .tracking(0.8)
                    .frame(height: 11)
                    .accessibilityHidden(yabaiQualifier == nil)
            }
        } else if presentation.isPomodoroLayer {
            PomodoroHeaderView(
                title: presentation.label,
                status: pomodoroStatus,
                width: contentWidth
            )
        } else {
            LayerTitleText(label: presentation.label)
        }
    }

    @ViewBuilder
    private var holdLegendView: some View {
        if presentation.isYabaiLayer && !showInputPath {
            YabaiModifierLegend(activeModifiers: activeModifiers)
        } else if presentation.hasHoldModifiers && !showInputPath {
            Text("KEY ↖   TAP ●   HOLD ↘")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.overlay0)
                .tracking(1.2)
        }
    }

    @ViewBuilder
    private var groupLegendView: some View {
        if !showInputPath && !presentation.groups.isEmpty {
            HStack(spacing: 24) {
                ForEach(presentation.groups) { group in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: group.colorHex))
                            .frame(width: 8, height: 8)
                        Text(group.id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.overlay0)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var geometryContent: some View {
        let metrics = KeyboardGeometryMetrics(
            keySize: keySize,
            spacing: Self.keySpacing
        )
        geometryView(metrics: metrics)
            .environment(\.isYabaiLayer, presentation.isYabaiLayer)
    }

    @ViewBuilder
    private func geometryView(metrics: KeyboardGeometryMetrics) -> some View {
        switch presentation.geometry {
        case .macbook(let rows, let arrows):
            MacBookGeometryView(
                rows: rows,
                arrows: arrows,
                source: presentation.source,
                metrics: metrics,
                contentWidth: contentWidth
            )
        case .defy(let left, let right):
            DefyGeometryView(
                left: left,
                right: right,
                source: presentation.source,
                metrics: metrics,
                showInputPath: showInputPath
            )
        case .legacy(let rows, let arrows, let thumbs):
            LegacyKeyboardGeometryView(
                rows: rows,
                arrows: arrows,
                thumbs: thumbs,
                source: presentation.source,
                metrics: metrics,
                contentWidth: contentWidth
            )
        }
    }
}
