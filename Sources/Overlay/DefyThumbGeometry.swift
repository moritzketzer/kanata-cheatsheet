import SwiftUI


struct DefyThumbKeyGeometry: Identifiable {
    let id: String
    let outline: [CGPoint]
    let content: CGRect

    var path: Path {
        Path { path in
            path.addLines(outline)
            path.closeSubpath()
        }
    }
}


struct DefyThumbGeometry {
    let keys: [DefyThumbKeyGeometry]
    let size: CGSize

    static func isIdentified(
        left: KeyboardPresentedDefyThumbRows,
        right: KeyboardPresentedDefyThumbRows
    ) -> Bool {
        left.top.map { $0?.physicalId } == ["LT1", "LT2", "LT3", "LT4"]
            && left.bottom.map { $0?.physicalId } == ["LT5", "LT6", "LT7", "LT8"]
            && right.top.map { $0?.physicalId } == ["RT4", "RT3", "RT2", "RT1"]
            && right.bottom.map { $0?.physicalId } == ["RT8", "RT7", "RT6", "RT5"]
    }

    init(side: KeyboardHalfSide, keySize: CGFloat) {
        // Independently drawn approximations, not Bazecor SVG paths. The array
        // is physical position order 1...8, independent of firmware carriers.
        let outlines: [[CGPoint]] = [
            [(0, 0), (1.40, 0.10), (1.25, 1.05), (0, 0.85)],
            [(1.52, 0.12), (2.60, 0.28), (2.17, 1.20), (1.36, 1.06)],
            [(2.73, 0.33), (3.75, 0.78), (3.03, 1.65), (2.30, 1.25)],
            [(3.87, 0.91), (4.55, 1.80), (3.50, 2.34), (3.17, 1.73)],
            [(0, 0.98), (1.22, 1.18), (1.05, 2.25), (0.16, 2.04)],
            [(1.35, 1.23), (2.17, 1.40), (1.80, 2.40), (1.19, 2.27)],
            [(2.29, 1.47), (3.10, 1.90), (2.73, 2.85), (1.92, 2.62)],
            [(2.68, 2.92), (3.65, 2.53), (4.67, 2.03), (4.59, 3.58), (3.31, 4.10)],
        ].map { $0.map { CGPoint(x: $0.0, y: $0.1) } }
        let contentRects = [
            CGRect(x: 0.13, y: 0.19, width: 0.97, height: 0.65),
            CGRect(x: 1.56, y: 0.35, width: 0.60, height: 0.68),
            CGRect(x: 2.73, y: 0.75, width: 0.40, height: 0.68),
            CGRect(x: 3.60, y: 1.38, width: 0.44, height: 0.68),
            CGRect(x: 0.28, y: 1.27, width: 0.67, height: 0.70),
            CGRect(x: 1.47, y: 1.46, width: 0.38, height: 0.75),
            CGRect(x: 2.24, y: 1.98, width: 0.45, height: 0.72),
            CGRect(x: 3.36, y: 3.05, width: 0.90, height: 0.65),
        ]
        // Small keys need extra label room; large diagrams use 1:1 proportions.
        let scale = min(keySize * 1.3, max(keySize, 64))
        // Reserve the stroke and round outward instead of clipping at a
        // floating-point Path bounding box.
        let width = ceil(outlines.flatMap { $0 }.map(\.x).max()! * scale) + 2
        let height = ceil(outlines.flatMap { $0 }.map(\.y).max()! * scale) + 2
        size = CGSize(width: width, height: height)
        keys = outlines.enumerated().map { index, outline in
            let rect = contentRects[index]
            return DefyThumbKeyGeometry(
                id: "\(side == .left ? "L" : "R")T\(index + 1)",
                outline: outline.map { point in
                    CGPoint(
                        x: side == .left ? 1 + point.x * scale : width - 1 - point.x * scale,
                        y: 1 + point.y * scale
                    )
                },
                content: CGRect(
                    x: side == .left ? 1 + rect.minX * scale : width - 1 - rect.maxX * scale,
                    y: 1 + rect.minY * scale,
                    width: rect.width * scale,
                    height: rect.height * scale
                )
            )
        }
    }
}
