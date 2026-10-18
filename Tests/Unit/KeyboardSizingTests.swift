import CoreGraphics
import Testing


/// Characterization of the pure key-size math the keyboard view relies on.
/// The expected numbers are the values the shipped layout renders today.
@Suite("Keyboard Sizing")
struct KeyboardSizingTests {
    @Test(
        "content width is the display share minus the overlay padding",
        arguments: [
            (CGFloat(1440), 75, CGFloat(1016)),
            (CGFloat(3008), 75, CGFloat(2192)),
            (CGFloat(1800), 50, CGFloat(836)),
            (CGFloat(1440), 25, CGFloat(296)),
        ]
    )
    func contentWidth(_ screenWidth: CGFloat, _ widthPercent: Int, _ expected: CGFloat) {
        #expect(
            KeyboardGeometryMetrics.contentWidth(
                screenWidth: screenWidth,
                widthPercent: widthPercent
            ) == expected
        )
    }

    @Test(
        "MacBook key size reserves three arrow columns on the bottom row",
        arguments: [
            (CGFloat(300), CGFloat(13.58904109589041)),
            (CGFloat(1016), CGFloat(52.821917808219176)),
            (CGFloat(2192), CGFloat(117.26027397260275)),
        ]
    )
    func macBookKeySize(_ contentWidth: CGFloat, _ expected: CGFloat) {
        #expect(
            KeyboardGeometryMetrics.macBookKeySize(
                rows: macBookRows,
                contentWidth: contentWidth,
                spacing: 4
            ) == expected
        )
    }

    @Test("MacBook key size consumes the gaps it reserves")
    func macBookKeySizeWithoutGaps() {
        #expect(
            KeyboardGeometryMetrics.macBookKeySize(
                rows: macBookRows,
                contentWidth: 1016,
                spacing: 0
            ) == 55.67123287671233
        )
        // No rows still leaves the three arrow columns and their two gaps.
        #expect(
            KeyboardGeometryMetrics.macBookKeySize(
                rows: [],
                contentWidth: 1016,
                spacing: 4
            ) == 336
        )
    }

    @Test(
        "legacy key size divides the widest row",
        arguments: [
            (CGFloat(300), CGFloat(17.714285714285715)),
            (CGFloat(1016), CGFloat(68.85714285714286)),
            (CGFloat(2192), CGFloat(152.85714285714286)),
        ]
    )
    func legacyKeySize(_ contentWidth: CGFloat, _ expected: CGFloat) {
        #expect(
            KeyboardGeometryMetrics.legacyKeySize(
                rows: legacyRows,
                contentWidth: contentWidth,
                spacing: 4
            ) == expected
        )
    }

    @Test("legacy key size falls back to fourteen units without rows")
    func legacyKeySizeWithoutRows() {
        #expect(
            KeyboardGeometryMetrics.legacyKeySize(
                rows: [],
                contentWidth: 1016,
                spacing: 4
            ) == 72.57142857142857
        )
    }

    @Test(
        "Defy key size divides both halves and the center gap",
        arguments: [
            (CGFloat(300), CGFloat(28), CGFloat(64)),
            (CGFloat(1016), CGFloat(59.364151916136784), CGFloat(64)),
            (
                CGFloat(2192),
                CGFloat(128.07698917339746),
                CGFloat(128.07698917339746)
            ),
        ]
    )
    func defyKeySize(
        _ contentWidth: CGFloat,
        _ expected: CGFloat,
        _ expectedWithInputPath: CGFloat
    ) {
        #expect(
            KeyboardGeometryMetrics.defyKeySize(
                contentWidth: contentWidth,
                showInputPath: false
            ) == expected
        )
        #expect(
            KeyboardGeometryMetrics.defyKeySize(
                contentWidth: contentWidth,
                showInputPath: true
            ) == expectedWithInputPath
        )
    }

    @Test("every geometry keeps the readable key size floor")
    func keySizeFloor() {
        for geometry in [macBookGeometry, legacyGeometry, defyGeometry] {
            #expect(
                KeyboardGeometryMetrics.keySize(
                    for: geometry,
                    contentWidth: 300,
                    showInputPath: false,
                    spacing: 4
                ) == KeyboardGeometryMetrics.minimumKeySize
            )
        }
        #expect(KeyboardGeometryMetrics.minimumKeySize == 28)
    }

    @Test("the input path floor lifts the Defy halves only")
    func keySizeWithInputPath() {
        func size(_ geometry: KeyboardPresentedGeometry, showInputPath: Bool) -> CGFloat {
            KeyboardGeometryMetrics.keySize(
                for: geometry,
                contentWidth: 1016,
                showInputPath: showInputPath,
                spacing: 4
            )
        }

        #expect(size(defyGeometry, showInputPath: false) == 59.364151916136784)
        #expect(
            size(defyGeometry, showInputPath: true)
                == KeyboardGeometryMetrics.defyInputPathMinimumKeySize
        )
        for geometry in [macBookGeometry, legacyGeometry] {
            #expect(
                size(geometry, showInputPath: true)
                    == size(geometry, showInputPath: false)
            )
        }
    }

    @Test("each geometry picks its own key size math")
    func keySizePerGeometry() {
        func size(_ geometry: KeyboardPresentedGeometry) -> CGFloat {
            KeyboardGeometryMetrics.keySize(
                for: geometry,
                contentWidth: 2192,
                showInputPath: false,
                spacing: 4
            )
        }

        #expect(size(macBookGeometry) == 117.26027397260275)
        #expect(size(legacyGeometry) == 152.85714285714286)
        #expect(size(defyGeometry) == 128.07698917339746)
    }

    private var macBookGeometry: KeyboardPresentedGeometry {
        .macbook(rows: macBookRows, arrows: arrows)
    }

    private var legacyGeometry: KeyboardPresentedGeometry {
        .legacy(rows: legacyRows, arrows: nil, thumbs: nil)
    }

    private var defyGeometry: KeyboardPresentedGeometry {
        .defy(left: defyHalf, right: defyHalf)
    }

    private var macBookRows: [[KeyboardPresentedKey]] {
        [
            row(Array(repeating: 1, count: 13)),
            row(Array(repeating: 1, count: 13) + [1.5]),
            row([1.5] + Array(repeating: 1, count: 12)),
            row([1.75] + Array(repeating: 1, count: 12) + [1.75]),
            row([1.25] + Array(repeating: 1, count: 11) + [1.75]),
            row([1, 1.25, 1.25, 1.25, 5, 1.25, 1.25, 1, 1, 1]),
        ]
    }

    private var legacyRows: [[KeyboardPresentedKey]] {
        [
            row(Array(repeating: 1, count: 14)),
            row(Array(repeating: 1, count: 12) + [2]),
        ]
    }

    private var arrows: KeyboardPresentedArrowCluster {
        KeyboardPresentedArrowCluster(
            up: key(1), left: key(1), down: key(1), right: key(1)
        )
    }

    private var defyHalf: KeyboardPresentedDefyHalf {
        KeyboardPresentedDefyHalf(
            rows: Array(repeating: Array(repeating: nil, count: 7), count: 4),
            thumbs: KeyboardPresentedDefyThumbRows(
                top: Array(repeating: nil, count: 4),
                bottom: Array(repeating: nil, count: 4)
            )
        )
    }

    private func row(_ widths: [Double]) -> [KeyboardPresentedKey] {
        widths.map { key($0) }
    }

    private func key(_ width: Double) -> KeyboardPresentedKey {
        KeyboardPresentedKey(
            id: "KeyA",
            width: width,
            badge: nil,
            actionLabel: nil,
            freeLabel: nil,
            colorHex: nil,
            primary: nil,
            holdModifier: nil,
            explanation: nil
        )
    }
}
