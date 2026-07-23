import Foundation
import Testing


@Suite("Registry Icon Layout")
struct RegistryIconLayoutTests {
    @Test("app-font correction centers glyph ink")
    func appFontCorrection() {
        let safari = RegistryKeyIcon(kind: "app-font", token: ":safari:")
        let cmux = RegistryKeyIcon(kind: "app-font", token: ":cmux:")

        let safariCorrection = RegistryIconLayout.horizontalCorrection(
            for: safari,
            size: 40
        )
        let cmuxCorrection = RegistryIconLayout.horizontalCorrection(
            for: cmux,
            size: 40
        )

        #expect(abs(safariCorrection - 8.2) < 0.15)
        #expect(cmuxCorrection > safariCorrection)
    }

    @Test("SF Symbols keep their native geometry")
    func sfSymbolCorrection() {
        let icon = RegistryKeyIcon(kind: "sf-symbol", token: "mic.fill")
        #expect(RegistryIconLayout.horizontalCorrection(for: icon, size: 40) == 0)
    }

    @Test("missing fonts fall back to the current position")
    func missingFontCorrection() {
        let icon = RegistryKeyIcon(kind: "app-font", token: ":safari:")
        #expect(
            RegistryIconLayout.horizontalCorrection(
                for: icon,
                size: 40,
                fontName: "missing-test-font"
            ) == 0
        )
    }

    @Test("registry icons use the approved alpha")
    func iconOpacity() {
        #expect(RegistryIconLayout.opacity == 0.82)
    }
}
