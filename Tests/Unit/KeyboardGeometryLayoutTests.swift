import AppKit
import CoreGraphics
import SwiftUI
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

    @Test("input path labels follow Mine presentation priority")
    func inputPathLabelPriority() {
        let explanation = inputPathSlot(key: presentedKey(
            badge: "B",
            actionLabel: "Action",
            primary: RegistryKeyVisual(kind: "glyph", token: "Visual"),
            explanation: "Explanation",
            keyLabel: "Key"
        ))
        let visual = inputPathSlot(key: presentedKey(
            actionLabel: "Action",
            primary: RegistryKeyVisual(kind: "glyph", token: "Visual"),
            keyLabel: "Key"
        ))
        let keyLabel = inputPathSlot(key: presentedKey(
            actionLabel: "Action",
            keyLabel: "Key"
        ))
        let action = inputPathSlot(key: presentedKey(actionLabel: "Action"))
        let badge = inputPathSlot(key: presentedKey(badge: "C"))

        #expect(KeyboardInputPathLabels.resolve(explanation).mine == "Explanation")
        #expect(KeyboardInputPathLabels.resolve(visual).mine == "Visual")
        #expect(KeyboardInputPathLabels.resolve(keyLabel).mine == "Key")
        #expect(KeyboardInputPathLabels.resolve(action).mine == "Action")
        #expect(KeyboardInputPathLabels.resolve(badge).mine == "C")
    }

    @Test("input path labels append the Home Row Mod hold glyph")
    func inputPathHomeRowMod() {
        let slot = inputPathSlot(key: presentedKey(
            badge: "C",
            holdModifier: "control"
        ))
        let labels = KeyboardInputPathLabels.resolve(slot)

        #expect(labels.firmware == "A")
        #expect(labels.source == "a")
        #expect(labels.mine == "C / ⌃")
        #expect(!labels.isDeviceLocal)
    }

    @Test("input path distinguishes device-local keys from structural vacancies")
    func inputPathSlotKinds() {
        let deviceLocal = KeyboardPresentedDefySlot(
            firmwareKey: "Bluetooth Pairing",
            sourceKey: nil,
            key: nil
        )
        let labels = KeyboardInputPathLabels.resolve(deviceLocal)

        #expect(labels.firmware == "Bluetooth Pairing")
        #expect(labels.source == nil)
        #expect(labels.mine == nil)
        #expect(labels.isDeviceLocal)
        #expect(
            DefySlotRenderKind(slot: deviceLocal, showInputPath: true)
                == .inputPath(deviceLocal)
        )
        #expect(
            DefySlotRenderKind(slot: nil, showInputPath: true)
                == .vacancy
        )
    }

    @Test("input path caption names all three levels")
    func inputPathCaption() {
        #expect(
            KeyboardInputPathLabels.caption
                == "FIRMWARE -> KANATA SOURCE -> MINE (TAP / HOLD)"
        )
    }

    @Test("long input path labels stay inside one Defy cell")
    @MainActor
    func longInputPathLabelsFit() {
        let width: CGFloat = 64
        let height: CGFloat = 64
        let slot = KeyboardPresentedDefySlot(
            firmwareKey: "Bluetooth Pairing",
            sourceKey: "international_backslash",
            key: presentedKey(
                actionLabel: "Scroll / Symbols",
                holdModifier: "command"
            )
        )
        let host = NSHostingView(rootView: KeyboardInputPathCell(
            slot: slot,
            width: width,
            height: height
        ))
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize.width <= width)
        #expect(host.fittingSize.height <= height)
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

    private func inputPathSlot(
        key: KeyboardPresentedKey
    ) -> KeyboardPresentedDefySlot {
        KeyboardPresentedDefySlot(
            firmwareKey: "A",
            sourceKey: "a",
            key: key
        )
    }

    private func presentedKey(
        badge: String? = nil,
        actionLabel: String? = nil,
        primary: RegistryKeyVisual? = nil,
        holdModifier: String? = nil,
        explanation: String? = nil,
        keyLabel: String? = nil
    ) -> KeyboardPresentedKey {
        KeyboardPresentedKey(
            id: "KeyA",
            width: 1,
            badge: badge,
            actionLabel: actionLabel,
            freeLabel: nil,
            colorHex: nil,
            primary: primary,
            holdModifier: holdModifier,
            explanation: explanation,
            keyLabel: keyLabel
        )
    }
}
