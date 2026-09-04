import CoreGraphics
import Testing


@Suite("Keyboard Geometry Layout")
struct KeyboardGeometryLayoutTests {
    @Test("MacBook arrows embed a half-height vertical pair")
    func macBookArrowMetrics() {
        let metrics = KeyboardGeometryMetrics(keySize: 48, spacing: 4)

        #expect(metrics.arrowHalfHeight == 22)
        #expect(abs(
            metrics.arrowHalfHeight * 2
                + metrics.arrowVerticalSpacing
                - metrics.keySize
        ) < 0.0001)
        #expect(metrics.functionKeyHeight == 34.56)
    }

    @Test("MacBook rows share one flush outer width")
    func macBookRowsShareOuterWidth() {
        let metrics = KeyboardGeometryMetrics(keySize: 48, spacing: 4)
        let targetWidth: CGFloat = 820
        let rowUnitWidths: [[Double]] = [
            Array(repeating: 1, count: 13),
            Array(repeating: 1, count: 13) + [1.5],
            [1.5] + Array(repeating: 1, count: 12),
            [1.75] + Array(repeating: 1, count: 12) + [1.75],
            [1.25] + Array(repeating: 1, count: 11) + [1.75],
            [1, 1.25, 1.25, 1.25, 5, 1.25, 1.25, 1, 1, 1],
        ]

        for unitWidths in rowUnitWidths {
            let keyWidths = metrics.macBookKeyWidths(
                unitWidths: unitWidths,
                targetWidth: targetWidth
            )
            let outerWidth = keyWidths.reduce(0, +)
                + CGFloat(max(0, keyWidths.count - 1)) * metrics.spacing

            #expect(keyWidths.count == unitWidths.count)
            #expect(abs(outerWidth - targetWidth) < 0.0001)
        }
    }

    @Test("Defy keeps four seven-coordinate rows and 4 plus 4 thumbs per side")
    func defyShape() {
        #expect(KeyboardGeometryMetrics.defyMainRowCounts == [7, 7, 7, 7])
        #expect(KeyboardGeometryMetrics.defyTopThumbCount == 4)
        #expect(KeyboardGeometryMetrics.defyBottomThumbCount == 4)

        let metrics = KeyboardGeometryMetrics(keySize: 48, spacing: 4)
        #expect(metrics.defyBottomThumbHeight == 37.44)
        #expect(metrics.defyCenterGap > metrics.keySize)
    }

    @Test("Defy bottom vacancies face the center and device-local slots stay physical")
    func defySlotKinds() {
        let mappedKey = KeyboardPresentedKey(
            id: "KeyQ",
            width: 1,
            badge: "J",
            actionLabel: nil,
            freeLabel: nil,
            colorHex: nil,
            primary: nil,
            holdModifier: nil,
            explanation: nil
        )
        let mapped = KeyboardPresentedDefySlot(
            firmwareKey: "Q",
            sourceKey: "q",
            key: mappedKey
        )
        let deviceLocal = KeyboardPresentedDefySlot(
            firmwareKey: "Battery Status",
            sourceKey: nil,
            key: nil
        )
        let leftBottom: [KeyboardPresentedDefySlot?] = [
            mapped, mapped, mapped, mapped, mapped, mapped, nil,
        ]
        let rightBottom: [KeyboardPresentedDefySlot?] = [
            nil, mapped, mapped, mapped, mapped, mapped, mapped,
        ]

        #expect(
            leftBottom.map { DefySlotRenderKind(slot: $0).isVacancy }
                == [false, false, false, false, false, false, true]
        )
        #expect(
            rightBottom.map { DefySlotRenderKind(slot: $0).isVacancy }
                == [true, false, false, false, false, false, false]
        )
        #expect(
            DefySlotRenderKind(slot: deviceLocal)
                == .quiet(firmwareKey: "Battery Status")
        )
        #expect(DefySlotRenderKind(slot: mapped) == .key(mappedKey))
    }

    @Test("Defy column stagger mirrors across the center gap")
    func defyColumnStaggerMirrors() {
        let metrics = KeyboardGeometryMetrics(keySize: 48, spacing: 4)
        let left = metrics.defyColumnOffsets(for: .left)
        let right = metrics.defyColumnOffsets(for: .right)

        #expect(left.count == 7)
        #expect(right == Array(left.reversed()))
        #expect(Set(left).count > 2)
    }
}
