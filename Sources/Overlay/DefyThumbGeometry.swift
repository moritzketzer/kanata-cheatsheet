import SwiftUI


struct DefyThumbKeyGeometry: Identifiable {
    let id: String
    let outline: [CGPoint]
    let content: CGRect

    var path: Path {
        Path { path in
            let radius = min(content.width, content.height) * 0.15
            for index in outline.indices {
                let vertex = outline[index]
                let previous = outline[(index + outline.count - 1) % outline.count]
                let next = outline[(index + 1) % outline.count]
                func inset(toward point: CGPoint) -> CGPoint {
                    let dx = point.x - vertex.x
                    let dy = point.y - vertex.y
                    let fraction = min(0.25, radius / hypot(dx, dy))
                    return CGPoint(x: vertex.x + dx * fraction, y: vertex.y + dy * fraction)
                }
                let entry = inset(toward: previous)
                let exit = inset(toward: next)
                if index == 0 { path.move(to: entry) } else { path.addLine(to: entry) }
                path.addQuadCurve(to: exit, control: vertex)
            }
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
            [(0.13, 0.00), (1.70, 0.16), (1.52, 1.10), (0.00, 0.87)],
            [(1.77, 0.18), (2.87, 0.36), (3.05, 0.46), (2.63, 1.30), (1.57, 1.10)],
            [(3.15, 0.43), (3.80, 0.72), (4.27, 1.07), (3.44, 1.80), (2.69, 1.32)],
            [(4.32, 1.17), (4.70, 2.40), (3.88, 2.69), (3.48, 1.84)],
            [(0.00, 0.95), (1.49, 1.18), (1.24, 2.26), (0.31, 2.10)],
            [(1.55, 1.19), (2.88, 1.53), (2.24, 2.49), (1.31, 2.28)],
            [(2.98, 1.57), (3.46, 2.02), (3.80, 2.73), (2.75, 3.04), (2.35, 2.51)],
            [(2.79, 3.09), (4.70, 2.51), (4.62, 3.24), (4.40, 3.52), (3.22, 3.80)],
        ].map { $0.map { CGPoint(x: $0.0, y: $0.1) } }
        let contentRects = [
            CGRect(x: 0.22, y: 0.24, width: 1.24, height: 0.62),
            CGRect(x: 1.87, y: 0.36, width: 0.78, height: 0.76),
            CGRect(x: 3.05, y: 0.73, width: 0.67, height: 0.76),
            CGRect(x: 3.80, y: 1.66, width: 0.63, height: 0.76),
            CGRect(x: 0.31, y: 1.19, width: 0.96, height: 0.76),
            CGRect(x: 1.53, y: 1.45, width: 0.84, height: 0.76),
            CGRect(x: 2.72, y: 2.04, width: 0.69, height: 0.76),
            CGRect(x: 3.54, y: 2.91, width: 0.80, height: 0.58),
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
