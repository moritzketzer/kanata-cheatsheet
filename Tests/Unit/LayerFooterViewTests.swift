import AppKit
import SwiftUI
import Testing


@Suite("Layer Footer View", .serialized)
struct LayerFooterViewTests {
    private var footer: RegistryLayerFooter {
        RegistryLayerFooter(sections: [
            RegistryLayerFooterSection(
                id: "homerow-holds",
                title: "Homerow holds",
                columns: ["Keys", "Hold"],
                rows: [
                    ["C / H", "Control"],
                    ["R / S", "Option"],
                    ["I / T", "Shift"],
                    ["E / N", "Command"],
                ]
            ),
            RegistryLayerFooterSection(
                id: "action-grammar",
                title: "Window · Space · Display grammar",
                columns: ["Keys", "Bare", "Option", "Shift", "Command", "Control"],
                rows: [
                    ["U↑ / I↓", "Stack next / previous", "Focus window", "Swap", "Warp", "Resize"],
                    ["R← / E→", "Space previous / next", "Focus window", "Move", "Move + follow", "Resize"],
                    ["C← / O→", "Focus display", "—", "Move", "Move + follow", "—"],
                ]
            ),
        ])
    }

    @Test("six-column footer fits the available width")
    @MainActor
    func footerFitsAvailableWidth() {
        let view = LayerFooterView(footer: footer, availableWidth: 980)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize

        #expect(size.width <= 980.5)
        #expect(size.height > 0)
    }

    @Test("ten global actions form a compact overview at laptop width")
    @MainActor
    func globalActionsFitCompactOverview() {
        let globalFooter = RegistryLayerFooter(sections: [
            RegistryLayerFooterSection(
                id: "global-actions",
                title: "Suchen, Wechseln, Erfassen",
                columns: ["Shortcut", "Aktion"],
                rows: (0..<10).map { index in
                    ["Control + Space \(index)", "Switch Windows from Active App"]
                }
            ),
        ])
        let host = NSHostingView(rootView: LayerFooterView(
            footer: globalFooter, availableWidth: 980
        ))

        #expect(host.fittingSize.width <= 980.5)
        #expect(host.fittingSize.height > 0)
        #expect(host.fittingSize.height <= 170)
    }

    @Test("keyboard footer adds height without horizontal overflow")
    @MainActor
    func keyboardFooterFitsOverlay() {
        let display = Config.Display(width_percent: 75)
        let withoutFooter = NSHostingView(rootView: KeyboardView(
            layerName: "yabai",
            legacyLayer: nil,
            display: display,
            registry: registry(footer: nil)
        ))
        let withFooter = NSHostingView(rootView: KeyboardView(
            layerName: "yabai",
            legacyLayer: nil,
            display: display,
            registry: registry(footer: footer)
        ))
        let targetWidth = (NSScreen.main?.frame.width ?? 1440)
            * CGFloat(display.width_percent) / 100

        #expect(withFooter.fittingSize.height > withoutFooter.fittingSize.height)
        #expect(withFooter.fittingSize.width <= targetWidth + 0.5)
    }

    @Test("Mine renders its global actions footer within the overlay")
    @MainActor
    func mineGlobalActionsFooterFitsOverlay() {
        let display = Config.Display(width_percent: 75)
        let globalFooter = RegistryLayerFooter(sections: [
            RegistryLayerFooterSection(
                id: "global-actions",
                title: "Global actions",
                columns: ["Keys", "Action"],
                rows: [["Control + Space", "Raycast"]]
            ),
        ])
        let withoutFooter = NSHostingView(rootView: KeyboardView(
            layerName: "mine", legacyLayer: nil, display: display,
            registry: registry(footer: nil, layerName: "mine")
        ))
        let view = KeyboardView(
            layerName: "mine", legacyLayer: nil, display: display,
            registry: registry(footer: globalFooter, layerName: "mine")
        )
        let withFooter = NSHostingView(rootView: view)

        #expect(view.presentation.footer == globalFooter)
        #expect(withFooter.fittingSize.height > withoutFooter.fittingSize.height)
        #expect(withFooter.fittingSize.width <= withoutFooter.fittingSize.width + 0.5)
    }

    @Test("Apps does not render global modifier-space slots")
    @MainActor
    func appsDoesNotRenderGlobalModifierSpace() {
        let display = Config.Display(width_percent: 75)
        let slots = (0..<15).map { index in
            ModifierSpaceSlot(
                modifiers: [], display: "Shortcut \(index)",
                state: "occupied", bindingIds: []
            )
        }
        let withoutSlots = NSHostingView(rootView: KeyboardView(
            layerName: "apps", legacyLayer: nil, display: display,
            registry: registry(footer: nil, layerName: "apps")
        ))
        let withSlots = NSHostingView(rootView: KeyboardView(
            layerName: "apps", legacyLayer: nil, display: display,
            registry: registry(footer: nil, layerName: "apps", slots: slots)
        ))

        #expect(withSlots.fittingSize == withoutSlots.fittingSize)
    }

    private func registry(
        footer: RegistryLayerFooter?,
        layerName: String = "yabai",
        slots: [ModifierSpaceSlot] = []
    ) -> KeybindingRegistry {
        let rows = (0..<5).map { row in
            (0..<14).map { column in
                RegistryKeyboardPosition(
                    position: "Key-\(row)-\(column)",
                    sourceKey: "source-\(row)-\(column)",
                    mineKey: "M\(row)-\(column)",
                    namedKey: nil,
                    width: 1
                )
            }
        }
        return KeybindingRegistry(
            schemaVersion: 2,
            providers: [],
            bindings: [],
            diagnostics: [],
            views: RegistryViews(
                modifierSpace: ModifierSpaceView(
                    id: "modifier-space",
                    label: "Modifier + Space",
                    slots: slots
                ),
                allBindings: AllBindingsView(
                    id: "all-bindings",
                    label: "All Bindings",
                    bindingIds: []
                ),
                keyboardLayers: KeyboardLayersView(
                    id: "keyboard-layers",
                    label: "Keyboard Layers",
                    geometry: RegistryKeyboardGeometry(
                        layoutId: "mine-iso",
                        rows: rows
                    ),
                    layers: [
                        layerName: RegistryKeyboardLayer(
                            id: layerName,
                            label: layerName.capitalized,
                            trigger: "manual",
                            overlayGroup: nil,
                            showBaseKeys: true,
                            footer: footer,
                            groups: [],
                            cells: [:]
                        ),
                    ]
                )
            )
        )
    }
}
