import SwiftUI


@available(macOS 14, *)
struct DefyThumbFan: View {
    let thumbs: KeyboardPresentedDefyThumbRows
    let side: KeyboardHalfSide
    let source: KeyboardPresentationSource
    let metrics: KeyboardGeometryMetrics
    let showInputPath: Bool

    var body: some View {
        let geometry = DefyThumbGeometry(side: side, keySize: metrics.keySize)
        let slots = (thumbs.top + thumbs.bottom).compactMap { $0 }
        ZStack(alignment: .topLeading) {
            ForEach(geometry.keys) { key in
                if let slot = slots.first(where: { $0.physicalId == key.id }) {
                    thumb(key, slot: slot)
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    @ViewBuilder
    private func thumb(_ geometry: DefyThumbKeyGeometry, slot: KeyboardPresentedDefySlot) -> some View {
        let rect = geometry.content
        switch DefySlotRenderKind(slot: slot, showInputPath: showInputPath) {
        case .key(let key):
            let cell = KeyCell(
                key: key, source: source,
                width: metrics.defyFanThumbWidth, height: metrics.defyFanThumbHeight,
                physicalId: geometry.id, showsShell: false, uniformThumbLayout: true
            )
            thumbShell(
                geometry, fill: cell.fillColor, stroke: cell.strokeColor,
                center: geometry.areaCenter
            ) {
                cell.accessibilityElement(children: .combine)
            }
        case .inputPath(let slot):
            let cell = KeyboardInputPathCell(
                slot: slot,
                width: metrics.defyFanInputPathSize, height: metrics.defyFanInputPathSize,
                isThumb: true, referenceKeySize: metrics.keySize
            )
            thumbShell(
                geometry, fill: cell.fillColor, stroke: cell.strokeColor,
                center: geometry.areaCenter
            ) {
                cell.content
            }
        case .quiet(let label):
            let labelHeight = max(8, metrics.keySize * 0.13)
            let cell = QuietKeyShell(label: label, width: rect.width, height: rect.height - labelHeight)
            thumbShell(
                geometry, fill: cell.fillColor, stroke: cell.strokeColor,
                center: CGPoint(x: rect.midX, y: rect.midY)
            ) {
                VStack(spacing: 0) {
                    physicalLabel(geometry.id, height: labelHeight)
                    cell.content
                }
                .frame(width: rect.width, height: rect.height)
            }
        case .vacancy:
            EmptyView()
        }
    }

    /// Fills and strokes the measured outline, then centers the slot content
    /// inside it.
    @ViewBuilder
    private func thumbShell<Content: View>(
        _ geometry: DefyThumbKeyGeometry,
        fill: Color,
        stroke: Color,
        center: CGPoint,
        @ViewBuilder content: () -> Content
    ) -> some View {
        geometry.path.fill(fill)
        geometry.path.stroke(stroke, lineWidth: 1)
        content().position(x: center.x, y: center.y)
    }

    private func physicalLabel(_ id: String, height: CGFloat) -> some View {
        Text(id)
            .font(.system(size: max(5, height * 0.85), weight: .semibold, design: .monospaced))
            .foregroundStyle(Palette.subtext0)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(height: height)
    }
}
