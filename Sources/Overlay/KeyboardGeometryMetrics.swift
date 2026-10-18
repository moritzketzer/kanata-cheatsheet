import SwiftUI


struct KeyboardGeometryMetrics: Equatable {
    static let defyMainRowCounts = [7, 7, 7, 7]
    static let defyTopThumbCount = 4
    static let defyBottomThumbCount = 4
    static let defyHalfWidthUnits: CGFloat = 536.0 / 68
    /// Columns the MacBook bottom row reserves for its embedded arrow cluster:
    /// left, the stacked up/down pair, and right.
    static let arrowClusterColumns = 3
    // The narrowest thumb must fit its ID and three diagnostic text lines.
    static let defyInputPathMinimumKeySize: CGFloat = 64
    // Readable floor for every geometry, and the factor the input path shares
    // between its caption and its cell lines.
    static let minimumKeySize: CGFloat = 28
    static let inputPathFontFactor: CGFloat = 0.16

    let keySize: CGFloat
    let spacing: CGFloat

    var arrowVerticalSpacing: CGFloat { spacing }
    var arrowHalfHeight: CGFloat { (keySize - arrowVerticalSpacing) / 2 }
    var functionKeyHeight: CGFloat { keySize * 0.72 }
    var defyTopThumbHeight: CGFloat { keySize * 0.9 }
    var defyBottomThumbHeight: CGFloat { keySize * 0.78 }
    var defyThumbWidth: CGFloat { keySize * 0.9 }
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

    var defyFanThumbWidth: CGFloat { keySize * 0.78 }
    var defyFanThumbHeight: CGFloat { keySize * 0.72 }
    var defyFanInputPathSize: CGFloat { keySize * 0.94 }

    var defyInputPathCaptionSpacing: CGFloat { keySize * 0.12 }
    var defyInputPathCaptionFontSize: CGFloat {
        keySize * Self.inputPathFontFactor
    }

    var legacyThumbWidth: CGFloat { keySize * 0.88 }
    var legacyThumbHeight: CGFloat { keySize * 0.72 }
    var legacyThumbTopOffset: CGFloat { keySize * 0.18 }

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
        // Measured per-thumb vertical stagger, as a fraction of the key size.
        let left = [0.12, 0.04, 0, 0.08].map { keySize * $0 }
        return side == .left ? left : Array(left.reversed())
    }

    /// Panel width the key rows may fill, after the overlay padding.
    static func contentWidth(
        screenWidth: CGFloat,
        widthPercent: Int,
        horizontalPadding: CGFloat = 64
    ) -> CGFloat {
        screenWidth * CGFloat(widthPercent) / 100 - horizontalPadding
    }

    /// Largest key size the geometry fits into `contentWidth`, never below the
    /// readable floor.
    static func keySize(
        for geometry: KeyboardPresentedGeometry,
        contentWidth: CGFloat,
        showInputPath: Bool,
        spacing: CGFloat
    ) -> CGFloat {
        let calculated: CGFloat
        switch geometry {
        case .macbook(let rows, _):
            calculated = macBookKeySize(
                rows: rows,
                contentWidth: contentWidth,
                spacing: spacing
            )
        case .defy:
            calculated = defyKeySize(
                contentWidth: contentWidth,
                showInputPath: showInputPath
            )
        case .legacy(let rows, _, _):
            calculated = legacyKeySize(
                rows: rows,
                contentWidth: contentWidth,
                spacing: spacing
            )
        }
        return max(minimumKeySize, calculated)
    }

    /// The bottom row carries the embedded arrow cluster, so it reserves
    /// `arrowClusterColumns` extra unit widths and the same number of gaps.
    static func macBookKeySize(
        rows: [[KeyboardPresentedKey]],
        contentWidth: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        let rowUnits = rows.map { row in
            CGFloat(row.map(\.width).reduce(0, +))
        }
        let ordinaryMaxUnits = rowUnits.max() ?? 1
        let bottomUnits = (rowUnits.last ?? 0) + CGFloat(arrowClusterColumns)
        let maxUnits = max(ordinaryMaxUnits, bottomUnits)
        let ordinaryMaxCount = rows.map(\.count).max() ?? 1
        let bottomCount = (rows.last?.count ?? 0) + arrowClusterColumns
        let gapCount = max(ordinaryMaxCount, bottomCount) - 1
        return (
            contentWidth - CGFloat(max(0, gapCount)) * spacing
        ) / max(1, maxUnits)
    }

    static func defyKeySize(
        contentWidth: CGFloat,
        showInputPath: Bool
    ) -> CGFloat {
        max(
            showInputPath ? defyInputPathMinimumKeySize : minimumKeySize,
            contentWidth / (2 * defyHalfWidthUnits + 1.35)
        )
    }

    static func legacyKeySize(
        rows: [[KeyboardPresentedKey]],
        contentWidth: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        let maxRowUnits = rows.map { row in
            CGFloat(row.map(\.width).reduce(0, +))
        }.max() ?? 14
        let maxKeyCount = rows.map(\.count).max() ?? 1
        let gaps = CGFloat(max(0, maxKeyCount - 1)) * spacing
        return (contentWidth - gaps) / max(1, maxRowUnits)
    }
}
