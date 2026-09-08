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

    @Test("Defy column stagger is softened to forty percent and mirrors across the center gap")
    func defyColumnStaggerMirrors() {
        let metrics = KeyboardGeometryMetrics(keySize: 48, spacing: 4)
        let left = metrics.defyColumnOffsets(for: .left)
        let right = metrics.defyColumnOffsets(for: .right)

        #expect(left.count == 7)
        #expect(right == Array(left.reversed()))
        let measuredOffsets: [CGFloat] = [41, 41, 15, 0, 15, 15, 51]
        let expected = measuredOffsets.map { $0 * 48 / 68 * 0.4 }
        #expect(left == expected)
        #expect(metrics.defyMainSpacing == CGFloat(48) * 2 / 68)
        let mainBottom = metrics.keySize * 4 + metrics.defyMainSpacing * 3 + left[4]
        #expect(metrics.defyThumbOrigin.y - mainBottom > 20)
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
                #expect(rect.width > 0 && rect.height > 0)
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

    @Test("Defy thumbs preserve the measured proportions and straight LT1 top")
    func measuredThumbSilhouette() {
        let geometry = DefyThumbGeometry(side: .left, keySize: 68)
        #expect(geometry.size.width / geometry.size.height > 1.40)
        #expect(geometry.size.width / geometry.size.height < 1.55)
        let top = geometry.keys[0].outline.filter { $0.y < 2 }
        #expect(top.map(\.x).max()! - top.map(\.x).min()! > 85)
    }

    @Test("adjacent thumb outlines preserve six-unit seams")
    func uniformThumbSeams() {
        let keys = DefyThumbGeometry(side: .left, keySize: 68).keys
        func distance(_ point: CGPoint, to a: CGPoint, _ b: CGPoint) -> CGFloat {
            let dx = b.x - a.x, dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            let fraction = max(0, min(1,
                ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared
            ))
            return hypot(point.x - a.x - fraction * dx, point.y - a.y - fraction * dy)
        }
        for (first, second) in [(0, 1), (1, 2), (2, 3), (0, 4), (1, 5),
                                (2, 6), (3, 6), (3, 7), (4, 5), (5, 6), (6, 7)] {
            let a = keys[first].outline, b = keys[second].outline
            var gap = CGFloat.infinity
            for (points, edges) in [(a, b), (b, a)] {
                for point in points {
                    for index in edges.indices {
                        gap = min(gap, distance(point, to: edges[index], edges[(index + 1) % edges.count]))
                    }
                }
            }
            #expect(abs(gap - 6) < 0.1, "LT\(first + 1) / LT\(second + 1) gap = \(gap)")
        }
    }

    @Test("small thumb input paths reserve readable firmware, source, and Mine lines", arguments: [KeyboardHalfSide.left, .right])
    @MainActor
    func smallThumbInputPath(_ side: KeyboardHalfSide) {
        let keySize = KeyboardGeometryMetrics.defyInputPathMinimumKeySize
        let rect = DefyThumbGeometry(side: side, keySize: keySize).keys[3].content
        let labelHeight = max(6, keySize * 0.13)
        #expect(rect.height - labelHeight >= 20)
        let slot = KeyboardPresentedDefySlot(
            firmwareKey: "Numpad2", sourceKey: "kp2", mineHoldModifier: nil,
            key: presentedKey(actionLabel: "Cut")
        )
        let labels = KeyboardInputPathLabels.resolve(slot)
        #expect(labels.firmware == "Numpad2")
        #expect(labels.source == "kp2")
        #expect(labels.mine == "Cut")
        let cell = KeyboardInputPathCell(
            slot: slot, width: rect.width, height: rect.height - labelHeight,
            isThumb: true
        )
        #expect(cell.primaryFontSize >= 4)
        #expect(cell.sourceFontSize >= 3.5)
        #expect(cell.minimumScaleFactor >= 0.85)
        let host = NSHostingView(rootView: cell.content)
        host.layoutSubtreeIfNeeded()
        // AppKit rounds the SwiftUI frame outward to whole points.
        #expect(host.fittingSize.height <= ceil(rect.height - labelHeight))
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
            let metrics = KeyboardGeometryMetrics(keySize: keySize, spacing: 4)
            #expect(fan.height >= metrics.defyHalfHeight)
            #expect(abs(fan.width - (2 * metrics.defyHalfWidth + metrics.defyCenterGap)) <= 1)
            for side in [KeyboardHalfSide.left, .right] {
                let geometry = DefyThumbGeometry(side: side, keySize: keySize)
                let bottom = geometry.keys.map { $0.path.boundingRect.maxY }.max()!
                #expect(metrics.defyThumbOrigin.y + bottom <= metrics.defyHalfHeight)
            }
            #expect(size(true, false) == legacy)
            #expect(size(false, true) == legacy)
        }
    }

    @Test("installed thumb cells can omit their rectangular shell")
    @MainActor
    func thumbCellWithoutShell() throws {
        func bitmap(showsShell: Bool) throws -> NSBitmapImageRep {
            let host = NSHostingView(rootView: KeyCell(
                key: presentedKey(), source: .registry, width: 64, height: 48,
                physicalId: "LT1", showsShell: showsShell
            ))
            host.frame = NSRect(x: 0, y: 0, width: 64, height: 48)
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            return bitmap
        }
        let ordinary = try bitmap(showsShell: true)
        let thumb = try bitmap(showsShell: false)
        #expect(ordinary.pixelsWide == thumb.pixelsWide)
        #expect(ordinary.pixelsHigh == thumb.pixelsHigh)
        let x = thumb.pixelsWide / 2
        let y = thumb.pixelsHigh * 3 / 4
        #expect(try #require(ordinary.colorAt(x: x, y: y)).alphaComponent > 0)
        #expect(try #require(thumb.colorAt(x: x, y: y)).alphaComponent == 0)
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
