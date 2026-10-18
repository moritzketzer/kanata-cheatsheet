import SwiftUI


@available(macOS 14, *)
struct MacBookGeometryView: View {
    let rows: [[KeyboardPresentedKey]]
    let arrows: KeyboardPresentedArrowCluster
    let source: KeyboardPresentationSource
    let metrics: KeyboardGeometryMetrics
    let contentWidth: CGFloat

    var body: some View {
        VStack(spacing: metrics.spacing) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                if rowIndex == rows.count - 1 {
                    bottomRow(rows[rowIndex])
                } else {
                    keyboardRow(
                        rows[rowIndex],
                        height: rowIndex == 0
                            ? metrics.functionKeyHeight
                            : metrics.keySize
                    )
                }
            }
        }
    }

    private func keyboardRow(
        _ row: [KeyboardPresentedKey],
        height: CGFloat
    ) -> some View {
        let widths = metrics.macBookKeyWidths(
            unitWidths: row.map(\.width),
            targetWidth: contentWidth
        )
        return HStack(spacing: metrics.spacing) {
            ForEach(Array(row.enumerated()), id: \.element.viewID) { index, key in
                KeyCell(
                    key: key,
                    source: source,
                    width: widths[index],
                    height: height
                )
            }
        }
    }

    private func bottomRow(_ row: [KeyboardPresentedKey]) -> some View {
        let widths = metrics.macBookKeyWidths(
            unitWidths: row.map(\.width) + [1, 1, 1],
            targetWidth: contentWidth
        )
        let arrowWidth = widths.last ?? metrics.keySize
        return HStack(alignment: .bottom, spacing: metrics.spacing) {
            ForEach(Array(row.enumerated()), id: \.element.viewID) { index, key in
                KeyCell(
                    key: key,
                    source: source,
                    width: widths[index],
                    height: metrics.keySize
                )
            }
            embeddedArrowCluster(keyWidth: arrowWidth)
        }
    }

    private func embeddedArrowCluster(keyWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: metrics.spacing) {
            KeyCell(
                key: arrows.left,
                source: source,
                width: keyWidth,
                height: metrics.keySize
            )
            VStack(spacing: metrics.arrowVerticalSpacing) {
                KeyCell(
                    key: arrows.up,
                    source: source,
                    width: keyWidth,
                    height: metrics.arrowHalfHeight
                )
                KeyCell(
                    key: arrows.down,
                    source: source,
                    width: keyWidth,
                    height: metrics.arrowHalfHeight
                )
            }
            KeyCell(
                key: arrows.right,
                source: source,
                width: keyWidth,
                height: metrics.keySize
            )
        }
    }
}
