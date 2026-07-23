import AppKit
import CoreText


enum RegistryIconLayout {
    static let opacity = 0.82

    static func horizontalCorrection(
        for icon: RegistryKeyIcon,
        size: CGFloat,
        fontName: String = "sketchybar-app-font"
    ) -> CGFloat {
        guard
            icon.kind == "app-font",
            let font = NSFont(name: fontName, size: size)
        else {
            return 0
        }

        let text = NSAttributedString(
            string: icon.token,
            attributes: [.font: font]
        )
        let line = CTLineCreateWithAttributedString(text)
        let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let ink = CTLineGetBoundsWithOptions(
            line,
            [.useGlyphPathBounds, .excludeTypographicLeading]
        )

        guard advance.isFinite, ink.width > 0 else { return 0 }
        return advance / 2 - ink.midX
    }
}
