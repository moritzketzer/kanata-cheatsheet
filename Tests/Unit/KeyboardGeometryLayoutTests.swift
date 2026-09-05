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
            mineHoldModifier: nil,
            key: mappedKey
        )
        let deviceLocal = KeyboardPresentedDefySlot(
            firmwareKey: "Battery Status",
            sourceKey: nil,
            mineHoldModifier: nil,
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

    @Test(
        "input path labels append all Mine Home Row Mod hold glyphs",
        arguments: [
            ("C", "control", "C / ⌃"),
            ("R", "option", "R / ⌥"),
            ("I", "shift", "I / ⇧"),
            ("E", "command", "E / ⌘"),
            ("N", "command", "N / ⌘"),
            ("T", "shift", "T / ⇧"),
            ("S", "option", "S / ⌥"),
            ("H", "control", "H / ⌃"),
        ]
    )
    func inputPathHomeRowMods(
        _ badge: String,
        _ modifier: String,
        _ expected: String
    ) {
        let slot = inputPathSlot(
            key: presentedKey(badge: badge),
            mineHoldModifier: modifier
        )
        let labels = KeyboardInputPathLabels.resolve(slot)

        #expect(labels.firmware == "A")
        #expect(labels.source == "a")
        #expect(labels.mine == expected)
        #expect(!labels.isDeviceLocal)
    }

    @Test("input path distinguishes device-local keys from structural vacancies")
    func inputPathSlotKinds() {
        let deviceLocal = KeyboardPresentedDefySlot(
            firmwareKey: "Bluetooth Pairing",
            sourceKey: nil,
            mineHoldModifier: nil,
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
            mineHoldModifier: "command",
            key: presentedKey(actionLabel: "Scroll / Symbols")
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

    @Test("Defy fan requires all sixteen IDs in physical array order")
    func identifiedThumbPair() {
        func rows(_ ids: [String?]) -> KeyboardPresentedDefyThumbRows {
            let slots = ids.map { id in
                KeyboardPresentedDefySlot(
                    firmwareKey: "F14", sourceKey: "f14", mineHoldModifier: nil,
                    key: nil, physicalId: id
                )
            }
            return KeyboardPresentedDefyThumbRows(top: Array(slots.prefix(4)), bottom: Array(slots.suffix(4)))
        }
        let left: [String?] = (1...8).map { "LT\($0)" }
        let right: [String?] = [4, 3, 2, 1, 8, 7, 6, 5].map { "RT\($0)" }
        #expect(DefyThumbGeometry.isIdentified(left: rows(left), right: rows(right)))
        for index in 0..<8 {
            for wrongID: String? in [nil, "LT9", "RT1", "LT\(index == 0 ? 2 : 1)"] {
                var invalid = left
                invalid[index] = wrongID
                #expect(!DefyThumbGeometry.isIdentified(left: rows(invalid), right: rows(right)))
            }
            var invalidRight = right
            invalidRight[index] = nil
            #expect(!DefyThumbGeometry.isIdentified(left: rows(left), right: rows(invalidRight)))
        }
        var swapped = right
        swapped.swapAt(0, 1)
        #expect(!DefyThumbGeometry.isIdentified(left: rows(left), right: rows(swapped)))
        #expect(!DefyThumbGeometry.isIdentified(left: rows(Array(repeating: nil, count: 8)), right: rows(right)))
    }

    @Test("Defy fan mirrors outlines and keeps horizontal content inside each key", arguments: [CGFloat(28), CGFloat(64)])
    func thumbFanGeometry(_ keySize: CGFloat) {
        let left = DefyThumbGeometry(side: .left, keySize: keySize)
        let right = DefyThumbGeometry(side: .right, keySize: keySize)
        #expect(left.keys.count == 8 && right.keys.count == 8)
        #expect(left.keys.map(\.id) == (1...8).map { "LT\($0)" })
        #expect(right.keys.map(\.id) == (1...8).map { "RT\($0)" })
        #expect(left.size == right.size)
        #expect(left.size.width < 7 * keySize)
        #expect(left.keys[0].path.boundingRect.width > left.keys[1].path.boundingRect.width)
        #expect(left.keys[7].path.boundingRect.height > left.keys[3].path.boundingRect.height)
        for (l, r) in zip(left.keys, right.keys) {
            #expect(abs(l.content.midX + r.content.midX - left.size.width) < 0.001)
            #expect(l.content.size == r.content.size)
            #expect(l.content.minY == r.content.minY)
            for (lp, rp) in zip(l.outline, r.outline) {
                #expect(abs(lp.x + rp.x - left.size.width) < 0.001)
                #expect(lp.y == rp.y)
            }
        }
        for geometry in [left, right] {
            for key in geometry.keys {
                let rect = key.content
                #expect(rect.height >= 20)
                for x in [rect.minX, rect.maxX] {
                    for y in [rect.minY, rect.maxY] {
                        #expect(key.path.contains(CGPoint(x: x, y: y)), "\(key.id) content corner")
                    }
                }
                #expect(CGRect(origin: .zero, size: geometry.size).contains(key.path.boundingRect))
            }
            // Sample interiors, not bounding rectangles: angled neighbors share bounds.
            for x in stride(from: CGFloat(0), through: geometry.size.width, by: keySize / 12) {
                for y in stride(from: CGFloat(0), through: geometry.size.height, by: keySize / 12) {
                    let point = CGPoint(x: x, y: y)
                    #expect(geometry.keys.filter { $0.path.contains(point) }.count <= 1)
                }
            }
        }
    }

    @Test("identified Defy views reserve the full fan and fall back as a pair", arguments: [CGFloat(28), CGFloat(64)])
    @MainActor
    func thumbFanViewSize(_ keySize: CGFloat) {
        func half(_ side: String, identified: Bool) -> KeyboardPresentedDefyHalf {
            let numbers = side == "L" ? Array(1...8) : [4, 3, 2, 1, 8, 7, 6, 5]
            let slots = numbers.map { number in
                KeyboardPresentedDefySlot(
                    firmwareKey: "F14", sourceKey: "f14", mineHoldModifier: nil,
                    key: presentedKey(actionLabel: "Space / Apps"),
                    physicalId: identified ? "\(side)T\(number)" : nil
                )
            }
            return KeyboardPresentedDefyHalf(
                rows: Array(repeating: Array(repeating: nil, count: 7), count: 4),
                thumbs: KeyboardPresentedDefyThumbRows(top: Array(slots.prefix(4)), bottom: Array(slots.suffix(4)))
            )
        }
        for inputPath in [false, true] {
            func size(_ left: Bool, _ right: Bool) -> CGSize {
                let host = NSHostingView(rootView: DefyGeometryView(
                    left: half("L", identified: left), right: half("R", identified: right),
                    source: .registry, metrics: KeyboardGeometryMetrics(keySize: keySize, spacing: 4),
                    showInputPath: inputPath
                ))
                host.layoutSubtreeIfNeeded()
                return host.fittingSize
            }
            let legacy = size(false, false)
            let fan = size(true, true)
            #expect(fan.height > legacy.height + keySize)
            #expect(abs(fan.width - legacy.width) < 0.001)
            #expect(size(true, false) == legacy)
            #expect(size(false, true) == legacy)
        }
    }

    private func inputPathSlot(
        key: KeyboardPresentedKey,
        mineHoldModifier: String? = nil
    ) -> KeyboardPresentedDefySlot {
        KeyboardPresentedDefySlot(
            firmwareKey: "A",
            sourceKey: "a",
            mineHoldModifier: mineHoldModifier,
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
