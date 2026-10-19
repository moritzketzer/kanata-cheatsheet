import SwiftUI


@available(macOS 14, *)
struct LegacyKeyboardGeometryView: View {
    let rows: [[KeyboardPresentedKey]]
    let arrows: KeyboardPresentedArrowCluster?
    let thumbs: KeyboardPresentedDefyThumbs?
    let source: KeyboardPresentationSource
    let metrics: KeyboardGeometryMetrics
    let contentWidth: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: metrics.spacing) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: metrics.spacing) {
                        ForEach(rows[rowIndex], id: \.viewID) { key in
                            KeyCell(
                                key: key,
                                source: source,
                                width: CGFloat(key.width) * metrics.keySize,
                                height: metrics.keySize
                            )
                        }
                    }
                }

                if let arrows {
                    HStack {
                        Spacer(minLength: 0)
                        legacyArrowBlock(arrows)
                    }
                    .frame(width: contentWidth)
                }
            }

            if let thumbs {
                thumbCluster(thumbs)
            }
        }
    }

    /// The labelled thumb block under the rows: the two halves fan apart, so
    /// each one takes the top row's offset in its own direction.
    private func thumbCluster(
        _ thumbs: KeyboardPresentedDefyThumbs
    ) -> some View {
        VStack(spacing: 6) {
            Text(thumbs.label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.overlay0)
                .tracking(2)
                .textCase(.uppercase)

            HStack(alignment: .bottom, spacing: metrics.keySize * 1.25) {
                legacyThumbHalf(
                    top: thumbs.leftTop,
                    bottom: thumbs.leftBottom,
                    topOffset: metrics.legacyThumbTopOffset
                )
                legacyThumbHalf(
                    top: thumbs.rightTop,
                    bottom: thumbs.rightBottom,
                    topOffset: -metrics.legacyThumbTopOffset
                )
            }
        }
    }

    private func legacyThumbHalf(
        top: [KeyboardPresentedKey],
        bottom: [KeyboardPresentedKey],
        topOffset: CGFloat
    ) -> some View {
        let thumbWidth = metrics.legacyThumbWidth
        let thumbHeight = metrics.legacyThumbHeight
        return VStack(spacing: metrics.spacing) {
            HStack(spacing: metrics.spacing) {
                ForEach(top, id: \.viewID) { key in
                    KeyCell(
                        key: key,
                        source: source,
                        width: CGFloat(key.width) * thumbWidth,
                        height: thumbHeight
                    )
                }
            }
            .offset(x: topOffset)

            HStack(spacing: metrics.spacing) {
                ForEach(bottom, id: \.viewID) { key in
                    KeyCell(
                        key: key,
                        source: source,
                        width: CGFloat(key.width) * thumbWidth,
                        height: thumbHeight
                    )
                }
            }
        }
    }

    private func legacyArrowBlock(
        _ arrows: KeyboardPresentedArrowCluster
    ) -> some View {
        Grid(
            horizontalSpacing: metrics.spacing,
            verticalSpacing: metrics.spacing
        ) {
            GridRow {
                Color.clear.frame(width: metrics.keySize, height: metrics.keySize)
                KeyCell(
                    key: arrows.up,
                    source: source,
                    width: metrics.keySize,
                    height: metrics.keySize
                )
                Color.clear.frame(width: metrics.keySize, height: metrics.keySize)
            }
            GridRow {
                ForEach([arrows.left, arrows.down, arrows.right], id: \.viewID) { key in
                    KeyCell(
                        key: key,
                        source: source,
                        width: metrics.keySize,
                        height: metrics.keySize
                    )
                }
            }
        }
    }
}
