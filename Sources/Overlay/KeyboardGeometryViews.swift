import SwiftUI


enum KeyboardHalfSide {
    case left
    case right
}


enum DefySlotRenderKind: Equatable {
    case vacancy
    case quiet(firmwareKey: String)
    case key(KeyboardPresentedKey)
    case inputPath(KeyboardPresentedDefySlot)

    init(
        slot: KeyboardPresentedDefySlot?,
        showInputPath: Bool = false
    ) {
        guard let slot else {
            self = .vacancy
            return
        }
        guard !showInputPath else {
            self = .inputPath(slot)
            return
        }
        guard let key = slot.key else {
            self = .quiet(firmwareKey: slot.firmwareKey)
            return
        }
        self = .key(key)
    }

    var isVacancy: Bool {
        if case .vacancy = self { return true }
        return false
    }
}


struct KeyboardInputPathLabels: Equatable {
    static let caption = "FIRMWARE -> KANATA SOURCE -> MINE (TAP / HOLD)"

    let firmware: String
    let source: String?
    let mine: String?
    let isDeviceLocal: Bool

    static func resolve(
        _ slot: KeyboardPresentedDefySlot
    ) -> KeyboardInputPathLabels {
        guard let key = slot.key else {
            return KeyboardInputPathLabels(
                firmware: slot.firmwareKey,
                source: nil,
                mine: nil,
                isDeviceLocal: true
            )
        }

        var tap = key.explanation
            ?? key.primary?.token
            ?? key.keyLabel
            ?? key.actionLabel
            ?? key.badge
        if let mineKey = slot.mineKey, let explanation = key.explanation,
           !explanation.contains(" / "), explanation != mineKey {
            tap = "\(mineKey) / \(explanation)"
        } else if let explanation = key.explanation, explanation.count > 20,
                  let badge = key.badge {
            tap = badge
        }
        let hold = (key.holdModifier ?? slot.mineHoldModifier).flatMap(
            KeyboardVisualSemantics.modifierGlyph
        )
        let mineParts = [tap, hold].compactMap { $0 }

        return KeyboardInputPathLabels(
            firmware: slot.firmwareKey,
            source: slot.sourceKey,
            mine: slot.mineDisabled ? "Disabled"
                : mineParts.isEmpty ? nil : mineParts.joined(separator: " / "),
            isDeviceLocal: false
        )
    }
}


struct KeyboardGeometryMetrics: Equatable {
    static let defyMainRowCounts = [7, 7, 7, 7]
    static let defyTopThumbCount = 4
    static let defyBottomThumbCount = 4
    static let defyHalfWidthUnits: CGFloat = 536.0 / 68
    // The narrowest thumb must fit its ID and three diagnostic text lines.
    static let defyInputPathMinimumKeySize: CGFloat = 64

    let keySize: CGFloat
    let spacing: CGFloat

    var arrowVerticalSpacing: CGFloat { spacing }
    var arrowHalfHeight: CGFloat { (keySize - arrowVerticalSpacing) / 2 }
    var functionKeyHeight: CGFloat { keySize * 0.72 }
    var defyTopThumbHeight: CGFloat { keySize * 0.9 }
    var defyBottomThumbHeight: CGFloat { keySize * 0.78 }
    var defyCenterGap: CGFloat { keySize * 1.35 }
    // Measured main key = 68 reference units; the thumb origin includes
    // 28 units of additional vertical space from the approved polish.
    var defyMainSpacing: CGFloat { keySize * 2 / 68 }
    var defyMainWidth: CGFloat { keySize * 488 / 68 }
    var defyHalfWidth: CGFloat { keySize * Self.defyHalfWidthUnits }
    var defyHalfHeight: CGFloat { keySize * 549 / 68 }
    var defyThumbOrigin: CGPoint {
        CGPoint(x: keySize * 206 / 68, y: keySize * 325 / 68)
    }

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
        let pixels: [CGFloat] = [41, 41, 15, 0, 15, 15, 51]
        // Retain 40% of the physical stagger so rows are easier to scan.
        let left = pixels.map {
            keySize * $0 / 68 * 0.4
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
    let showInputPath: Bool

    var body: some View {
        VStack(spacing: metrics.keySize * 0.16) {
            if showInputPath {
                HStack(spacing: metrics.keySize * 0.12) {
                    Text("Firmware").foregroundStyle(Color(hex: "#a6adc8"))
                    Text("→").foregroundStyle(Color(hex: "#9696aa"))
                    Text("Kanata Source").foregroundStyle(Color(hex: "#cdd6f4"))
                    Text("→").foregroundStyle(Color(hex: "#9696aa"))
                    Text("Mine").foregroundStyle(Color(hex: "#cdd6f4"))
                    Text("(Tap / Hold: Base-Farben)").foregroundStyle(Color(hex: "#9696aa"))
                }
                .font(.system(size: metrics.keySize * 0.16, weight: .semibold))
                .padding(.bottom, metrics.keySize * 0.12)
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
                    keySize: metrics.keySize, showInputPath: showInputPath
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


@available(macOS 14, *)
private struct DefyThumbFan: View {
    let thumbs: KeyboardPresentedDefyThumbRows
    let side: KeyboardHalfSide
    let source: KeyboardPresentationSource
    let keySize: CGFloat
    let showInputPath: Bool

    var body: some View {
        let geometry = DefyThumbGeometry(side: side, keySize: keySize)
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
                key: key, source: source, width: keySize * 0.78, height: keySize * 0.72,
                physicalId: geometry.id, showsShell: false, uniformThumbLayout: true
            )
            geometry.path.fill(cell.fillColor)
            geometry.path.stroke(cell.strokeColor, lineWidth: 1)
            cell.position(x: geometry.areaCenter.x, y: geometry.areaCenter.y)
                .accessibilityElement(children: .combine)
        case .inputPath(let slot):
            let cell = KeyboardInputPathCell(
                slot: slot, width: keySize * 0.94, height: keySize * 0.94,
                isThumb: true, referenceKeySize: keySize
            )
            geometry.path.fill(cell.fillColor)
            geometry.path.stroke(cell.strokeColor, lineWidth: 1)
            cell.content
                .position(x: geometry.areaCenter.x, y: geometry.areaCenter.y)
        case .quiet(let label):
            let labelHeight = max(8, keySize * 0.13)
            let cell = QuietKeyShell(label: label, width: rect.width, height: rect.height - labelHeight)
            geometry.path.fill(cell.fillColor)
            geometry.path.stroke(cell.strokeColor, lineWidth: 1)
            VStack(spacing: 0) {
                physicalLabel(geometry.id, height: labelHeight)
                cell.content
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
        case .vacancy:
            EmptyView()
        }
    }

    private func physicalLabel(_ id: String, height: CGFloat) -> some View {
        Text(id)
            .font(.system(size: max(5, height * 0.85), weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(hex: "#a6adc8"))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(height: height)
    }
}


@available(macOS 14, *)
struct KeyboardInputPathCell: View {
    let slot: KeyboardPresentedDefySlot
    let width: CGFloat
    let height: CGFloat
    var isThumb: Bool = false

    var referenceKeySize: CGFloat? = nil

    var primaryFontSize: CGFloat { (referenceKeySize ?? height) * 0.16 }

    private var labels: KeyboardInputPathLabels {
        KeyboardInputPathLabels.resolve(slot)
    }

    private var accessibilityText: String {
        if labels.isDeviceLocal {
            return "Firmware \(labels.firmware), device local"
        }
        return [
            "Firmware \(labels.firmware)",
            labels.source.map { "Kanata source \($0)" },
            labels.mine.map { "Mine \($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    var fillColor: Color { Color(hex: "#313244").opacity(0.34) }
    var strokeColor: Color { Color(hex: "#484858") }

    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 6).fill(fillColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: 1))
    }

    private var mineText: AttributedString {
        let value = labels.mine ?? "-"
        let neutral = Color(hex: "#cdd6f4")
        let muted = Color(hex: "#a6adc8")
        let action = slot.key?.colorHex.map(Color.init(hex:)) ?? neutral
        var text = AttributedString(value)
        text.foregroundColor = slot.mineDisabled || labels.mine == nil ? muted : action
        guard !slot.mineDisabled, let separator = value.range(of: " / ") else {
            return text
        }

        // Layer holds carry the action color; ordinary taps stay neutral.
        // Modifier holds follow Base's neutral modifier badge instead.
        let modifierHold = (slot.key?.holdModifier ?? slot.mineHoldModifier)
            .flatMap(KeyboardVisualSemantics.modifierGlyph) != nil
        var tap = AttributedString(String(value[..<separator.lowerBound]))
        tap.foregroundColor = modifierHold ? action : neutral
        var divider = AttributedString(value.count > (isThumb ? 10 : 11) ? "\n/ " : " / ")
        divider.foregroundColor = muted
        var hold = AttributedString(String(value[separator.upperBound...]))
        hold.foregroundColor = modifierHold ? neutral : action
        return tap + divider + hold
    }

    var content: some View {
        VStack(spacing: isThumb ? 0 : primaryFontSize * 0.30) {
            Text(labels.firmware)
                .foregroundStyle(Color(hex: "#a6adc8"))
            Text(labels.source ?? "-")
                .foregroundStyle(Color(hex: labels.source == nil ? "#a6adc8" : "#cdd6f4"))
            Text(mineText)
                .fontWeight(.semibold)
            if isThumb, let physicalId = slot.physicalId {
                Text(physicalId)
                    .font(.system(size: (referenceKeySize ?? height) * 0.10))
                    .foregroundStyle(Color(hex: "#9696aa"))
                    .padding(.top, primaryFontSize * 0.12)
            }
        }
        .font(.system(size: primaryFontSize))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: width - (isThumb ? 0 : 6), height: height)
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}


@available(macOS 14, *)
private struct QuietKeyShell: View {
    let label: String
    let width: CGFloat
    let height: CGFloat

    var fillColor: Color { Color(hex: "#313244").opacity(0.22) }
    var strokeColor: Color { Color(hex: "#cdd6f4").opacity(0.045) }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: 1))
            .overlay(content)
            .frame(width: width, height: height)
    }

    var content: some View {
        Text(label)
            .font(.system(size: height * 0.18, weight: .semibold))
            .foregroundStyle(Color(hex: "#cdd6f4").opacity(0.78))
            .lineLimit(2)
            .minimumScaleFactor(0.55)
            .multilineTextAlignment(.center)
            .padding(4)
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
