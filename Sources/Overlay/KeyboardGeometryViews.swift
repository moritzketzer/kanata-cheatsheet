import SwiftUI


enum KeyboardHalfSide {
    case left
    case right
}


struct KeyboardGeometryMetrics: Equatable {
    static let defyMainRowCounts = [7, 7, 7, 6]
    static let defyTopThumbCount = 4
    static let defyBottomThumbCount = 4

    let keySize: CGFloat
    let spacing: CGFloat

    var arrowVerticalSpacing: CGFloat { spacing }
    var arrowHalfHeight: CGFloat { (keySize - arrowVerticalSpacing) / 2 }
    var functionKeyHeight: CGFloat { keySize * 0.72 }
    var defyTopThumbHeight: CGFloat { keySize * 0.9 }
    var defyBottomThumbHeight: CGFloat { keySize * 0.78 }
    var defyCenterGap: CGFloat { keySize * 1.35 }

    func macBookKeyWidths(
        unitWidths: [Double],
        targetWidth: CGFloat
    ) -> [CGFloat] {
        guard !unitWidths.isEmpty else { return [] }

        let gapWidth = CGFloat(unitWidths.count - 1) * spacing
        let availableKeyWidth = max(0, targetWidth - gapWidth)
        let totalUnits = max(1, CGFloat(unitWidths.reduce(0, +)))
        return unitWidths.map {
            availableKeyWidth * CGFloat($0) / totalUnits
        }
    }

    func defyColumnOffsets(for side: KeyboardHalfSide) -> [CGFloat] {
        let left = [0.18, 0.12, 0.05, 0, 0.03, 0.10, 0.16].map {
            keySize * $0
        }
        return side == .left ? left : Array(left.reversed())
    }

    func defyThumbOffsets(for side: KeyboardHalfSide) -> [CGFloat] {
        let left = [0.12, 0.04, 0, 0.08].map { keySize * $0 }
        return side == .left ? left : Array(left.reversed())
    }
}


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


@available(macOS 14, *)
struct DefyGeometryView: View {
    let left: KeyboardPresentedDefyHalf
    let right: KeyboardPresentedDefyHalf
    let source: KeyboardPresentationSource
    let metrics: KeyboardGeometryMetrics

    var body: some View {
        HStack(alignment: .top, spacing: metrics.defyCenterGap) {
            half(left, side: .left)
            half(right, side: .right)
        }
    }

    private func half(
        _ half: KeyboardPresentedDefyHalf,
        side: KeyboardHalfSide
    ) -> some View {
        VStack(spacing: metrics.keySize * 0.2) {
            mainBody(half, side: side)
            thumbCluster(half.thumbs, side: side)
        }
    }

    private func mainBody(
        _ half: KeyboardPresentedDefyHalf,
        side: KeyboardHalfSide
    ) -> some View {
        let offsets = metrics.defyColumnOffsets(for: side)
        let width = metrics.keySize * 7 + metrics.spacing * 6
        let height = metrics.keySize * 4
            + metrics.spacing * 3
            + (offsets.max() ?? 0)

        return ZStack(alignment: .topLeading) {
            ForEach(0..<7, id: \.self) { column in
                ForEach(half.rows.indices, id: \.self) { row in
                    if column < half.rows[row].count {
                        defySlot(
                            half.rows[row][column],
                            width: metrics.keySize,
                            height: metrics.keySize
                        )
                        .offset(
                            x: CGFloat(column) * (metrics.keySize + metrics.spacing),
                            y: CGFloat(row) * (metrics.keySize + metrics.spacing)
                                + offsets[column]
                        )
                    }
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func thumbCluster(
        _ thumbs: KeyboardPresentedDefyThumbRows,
        side: KeyboardHalfSide
    ) -> some View {
        let halfWidth = metrics.keySize * 7 + metrics.spacing * 6
        let alignment: Alignment = side == .left ? .trailing : .leading

        return VStack(spacing: metrics.spacing) {
            thumbRow(
                thumbs.top,
                side: side,
                height: metrics.defyTopThumbHeight
            )
            thumbRow(
                thumbs.bottom,
                side: side,
                height: metrics.defyBottomThumbHeight
            )
        }
        .frame(width: halfWidth, alignment: alignment)
    }

    private func thumbRow(
        _ slots: [KeyboardPresentedKey?],
        side: KeyboardHalfSide,
        height: CGFloat
    ) -> some View {
        let offsets = metrics.defyThumbOffsets(for: side)
        return HStack(alignment: .top, spacing: metrics.spacing) {
            ForEach(slots.indices, id: \.self) { index in
                defySlot(
                    slots[index],
                    width: metrics.keySize * 0.9,
                    height: height
                )
                .offset(y: offsets[index])
            }
        }
        .padding(.bottom, offsets.max() ?? 0)
    }

    @ViewBuilder
    private func defySlot(
        _ key: KeyboardPresentedKey?,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        if let key {
            KeyCell(
                key: key,
                source: source,
                width: width,
                height: height
            )
        } else {
            QuietKeyShell(width: width, height: height)
        }
    }
}


@available(macOS 14, *)
private struct QuietKeyShell: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(hex: "#313244").opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "#cdd6f4").opacity(0.045), lineWidth: 1)
            )
            .frame(width: width, height: height)
    }
}


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
                VStack(spacing: 6) {
                    Text(thumbs.label)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#6c7086"))
                        .tracking(2)
                        .textCase(.uppercase)

                    HStack(alignment: .bottom, spacing: metrics.keySize * 1.25) {
                        legacyThumbHalf(
                            top: thumbs.leftTop,
                            bottom: thumbs.leftBottom,
                            topOffset: metrics.keySize * 0.18
                        )
                        legacyThumbHalf(
                            top: thumbs.rightTop,
                            bottom: thumbs.rightBottom,
                            topOffset: -metrics.keySize * 0.18
                        )
                    }
                }
            }
        }
    }

    private func legacyThumbHalf(
        top: [KeyboardPresentedKey],
        bottom: [KeyboardPresentedKey],
        topOffset: CGFloat
    ) -> some View {
        let thumbWidth = metrics.keySize * 0.88
        let thumbHeight = metrics.keySize * 0.72
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
                ForEach(arrows.allKeys.filter { $0.id != arrows.up.id }, id: \.viewID) { key in
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
