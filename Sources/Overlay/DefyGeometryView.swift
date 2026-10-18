import SwiftUI


@available(macOS 14, *)
struct DefyGeometryView: View {
    let left: KeyboardPresentedDefyHalf
    let right: KeyboardPresentedDefyHalf
    let source: KeyboardPresentationSource
    let metrics: KeyboardGeometryMetrics
    let showInputPath: Bool

    var body: some View {
        VStack(spacing: metrics.keySize * 0.16) {
            if showInputPath {
                HStack(spacing: metrics.defyInputPathCaptionSpacing) {
                    Text("Firmware").foregroundStyle(Palette.subtext0)
                    Text("→").foregroundStyle(Palette.inputPathArrow)
                    Text("Kanata Source").foregroundStyle(Palette.text)
                    Text("→").foregroundStyle(Palette.inputPathArrow)
                    Text("Mine").foregroundStyle(Palette.text)
                }
                .font(.system(
                    size: metrics.defyInputPathCaptionFontSize,
                    weight: .semibold
                ))
                .padding(.bottom, metrics.defyInputPathCaptionSpacing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(KeyboardInputPathLabels.caption)
            }

            HStack(alignment: .top, spacing: metrics.defyCenterGap) {
                half(left, side: .left)
                half(right, side: .right)
            }
        }
    }

    @ViewBuilder
    private func half(
        _ half: KeyboardPresentedDefyHalf,
        side: KeyboardHalfSide
    ) -> some View {
        if DefyThumbGeometry.isIdentified(left: left.thumbs, right: right.thumbs) {
            let thumbs = DefyThumbGeometry(side: side, keySize: metrics.keySize)
            ZStack(alignment: .topLeading) {
                mainBody(half, side: side)
                    .offset(x: side == .left ? 0 : metrics.defyHalfWidth - metrics.defyMainWidth)
                DefyThumbFan(
                    thumbs: half.thumbs, side: side, source: source,
                    metrics: metrics, showInputPath: showInputPath
                )
                .offset(
                    x: side == .left ? metrics.defyThumbOrigin.x
                        : metrics.defyHalfWidth - metrics.defyThumbOrigin.x - thumbs.size.width,
                    y: metrics.defyThumbOrigin.y
                )
            }
            .frame(width: metrics.defyHalfWidth, height: metrics.defyHalfHeight, alignment: .topLeading)
        } else {
            VStack(spacing: metrics.keySize * 0.2) {
                mainBody(half, side: side)
                thumbCluster(half.thumbs, side: side)
            }
        }
    }

    private func mainBody(
        _ half: KeyboardPresentedDefyHalf,
        side: KeyboardHalfSide
    ) -> some View {
        let offsets = metrics.defyColumnOffsets(for: side)
        let width = metrics.defyMainWidth
        let height = metrics.keySize * 4
            + metrics.defyMainSpacing * 3
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
                            x: CGFloat(column) * (metrics.keySize + metrics.defyMainSpacing),
                            y: CGFloat(row) * (metrics.keySize + metrics.defyMainSpacing)
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
        _ slots: [KeyboardPresentedDefySlot?],
        side: KeyboardHalfSide,
        height: CGFloat
    ) -> some View {
        let offsets = metrics.defyThumbOffsets(for: side)
        return HStack(alignment: .top, spacing: metrics.spacing) {
            ForEach(slots.indices, id: \.self) { index in
                defySlot(
                    slots[index],
                    width: metrics.defyThumbWidth,
                    height: height
                )
                .offset(y: offsets[index])
            }
        }
        .padding(.bottom, offsets.max() ?? 0)
    }

    @ViewBuilder
    private func defySlot(
        _ slot: KeyboardPresentedDefySlot?,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        switch DefySlotRenderKind(
            slot: slot,
            showInputPath: showInputPath
        ) {
        case .vacancy:
            Color.clear
                .frame(width: width, height: height)
                .accessibilityHidden(true)
        case .quiet(let firmwareKey):
            QuietKeyShell(label: firmwareKey, width: width, height: height)
        case .key(let key):
            KeyCell(
                key: key,
                source: source,
                width: width,
                height: height
            )
        case .inputPath(let slot):
            KeyboardInputPathCell(
                slot: slot,
                width: width,
                height: height
            )
        }
    }
}
