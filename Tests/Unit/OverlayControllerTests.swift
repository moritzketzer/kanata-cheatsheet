import Testing
import Foundation
import AppKit

@Suite("OverlayController Logic", .serialized)
struct OverlayControllerTests {
    private var appsConfig: Config {
        Config(
            display: Config.Display(delay_ms: 100),
            layers: ["apps": Config.Layer(label: "APPS", groups: [:])]
        )
    }

    @Test("configured layer starts delay")
    func configuredLayerStartsDelay() {
        let config = Config(
            display: Config.Display(delay_ms: 100),
            layers: ["nav": Config.Layer(label: "NAV", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        let action = logic.handleLayerChange("nav")
        #expect(action == .startDelay("nav"))
    }

    @Test("unconfigured layer hides immediately")
    func unconfiguredLayerHides() {
        let config = Config(layers: [:])
        let logic = OverlayLogic(config: config)
        let action = logic.handleLayerChange("mine")
        #expect(action == .hide)
    }

    @Test("layer change during delay cancels and starts new")
    func layerChangeDuringDelay() {
        let config = Config(
            display: Config.Display(delay_ms: 100),
            layers: [
                "nav": Config.Layer(label: "NAV", groups: [:]),
                "apps": Config.Layer(label: "APPS", groups: [:])
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        let action = logic.handleLayerChange("apps")
        #expect(action == .startDelay("apps"))
    }

    @Test("delay expiry triggers show")
    func delayExpiryShows() {
        let config = Config(
            display: Config.Display(delay_ms: 100),
            layers: ["nav": Config.Layer(label: "NAV", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        let action = logic.delayExpired()
        #expect(action == .show("nav"))
    }

    @Test("delay expiry for stale layer does nothing")
    func staleDelayIgnored() {
        let config = Config(
            display: Config.Display(delay_ms: 100),
            layers: ["nav": Config.Layer(label: "NAV", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        _ = logic.handleLayerChange("mine")
        let action = logic.delayExpired()
        #expect(action == .none)
    }

    @Test("visible overlay-group member replaces content in place")
    func visibleGroupedLayerReplacesInPlace() {
        let logic = OverlayLogic(config: Config(layers: [:]), registry: modifierSpaceRegistry(occupiedCount: 6))
        _ = logic.handleLayerChange("apps")
        _ = logic.delayExpired()

        #expect(logic.handleLayerChange("apps-alt") == .replace("apps-alt"))
        #expect(logic.visibleLayer == "apps-alt")
        #expect(logic.handleLayerChange("apps") == .replace("apps"))
        #expect(logic.visibleLayer == "apps")
    }

    @Test("pending overlay-group member retargets existing deadline")
    func pendingGroupedLayerRetargets() {
        let logic = OverlayLogic(config: Config(layers: [:]), registry: modifierSpaceRegistry(occupiedCount: 6))

        #expect(logic.handleLayerChange("apps") == .startDelay("apps"))
        #expect(logic.handleLayerChange("apps-alt") == .retargetDelay("apps-alt"))
        #expect(logic.delayExpired() == .show("apps-alt"))
    }

    @Test("leaving overlay group hides")
    func leavingGroupedLayerHides() {
        let logic = OverlayLogic(config: Config(layers: [:]), registry: modifierSpaceRegistry(occupiedCount: 6))
        _ = logic.handleLayerChange("apps")
        _ = logic.delayExpired()

        #expect(logic.handleLayerChange("mine") == .hide)
    }

    // MARK: - Manual trigger mode

    @Test("manual layer does not auto-show on delay")
    func manualLayerSkipsDelay() {
        let config = Config(
            layers: ["nav": Config.Layer(label: "NAV", trigger: "manual", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        let action = logic.handleLayerChange("nav")
        #expect(action == .none)
    }

    @Test("toggle shows overlay for current layer")
    func toggleShows() {
        let config = Config(
            layers: ["nav": Config.Layer(label: "NAV", trigger: "manual", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        let action = logic.handleMessage("cheatsheet-toggle")
        #expect(action == .show("nav"))
    }

    @Test("toggle hides when already visible")
    func toggleHides() {
        let config = Config(
            layers: ["nav": Config.Layer(label: "NAV", trigger: "manual", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        _ = logic.handleMessage("cheatsheet-show")
        let action = logic.handleMessage("cheatsheet-toggle")
        #expect(action == .hide)
    }

    @Test("show message works for current layer")
    func showMessage() {
        let config = Config(
            layers: ["nav": Config.Layer(label: "NAV", trigger: "manual", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        let action = logic.handleMessage("cheatsheet-show")
        #expect(action == .show("nav"))
    }

    @Test("hide message hides visible overlay")
    func hideMessage() {
        let config = Config(
            layers: ["nav": Config.Layer(label: "NAV", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        _ = logic.delayExpired()
        let action = logic.handleMessage("cheatsheet-hide")
        #expect(action == .hide)
    }

    @Test("unknown message does nothing")
    func unknownMessage() {
        let config = Config(
            layers: ["nav": Config.Layer(label: "NAV", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        let action = logic.handleMessage("something-else")
        #expect(action == .none)
    }

    @Test("layer change hides manual layer overlay")
    func layerChangeHidesManualOverlay() {
        let config = Config(
            layers: ["nav": Config.Layer(label: "NAV", trigger: "manual", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        _ = logic.handleMessage("cheatsheet-show")
        let action = logic.handleLayerChange("mine")
        #expect(action == .hide)
    }

    // MARK: - Parameterized show + same-layer LayerChange

    @Test("parameterized show uses target layer regardless of currentLayer")
    func parameterizedShow() {
        let config = Config(
            layers: [
                "apps": Config.Layer(label: "APPS", groups: [:]),
                "finder": Config.Layer(label: "FINDER", trigger: "manual", groups: [:])
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("apps")
        let action = logic.handleMessage("cheatsheet-show:finder")
        #expect(action == .show("finder"))
    }

    @Test("registry-backed layers work without legacy config entries")
    func registryBackedLayerIsConfigured() {
        let registry = modifierSpaceRegistry(occupiedCount: 6)
        let logic = OverlayLogic(config: Config(layers: [:]), registry: registry)

        #expect(logic.handleLayerChange("apps") == .startDelay("apps"))
    }

    @Test("parameterized show ignored if layer not in config")
    func parameterizedShowUnknownLayer() {
        let config = Config(layers: ["nav": Config.Layer(label: "NAV", trigger: "manual", groups: [:])])
        let logic = OverlayLogic(config: config)
        let action = logic.handleMessage("cheatsheet-show:nonexistent")
        #expect(action == .none)
    }

    @Test("LayerChange to currently visible manual layer does not hide")
    func sameLayerLayerChangeDoesNotHide() {
        let config = Config(
            layers: ["finder": Config.Layer(label: "FINDER", trigger: "manual", groups: [:])]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleMessage("cheatsheet-show:finder")
        let action = logic.handleLayerChange("finder")
        #expect(action == .none)
    }

    @Test("LayerChange to different manual layer hides")
    func differentManualLayerLayerChangeHides() {
        let config = Config(
            layers: [
                "apps": Config.Layer(label: "APPS", trigger: "manual", groups: [:]),
                "finder": Config.Layer(label: "FINDER", trigger: "manual", groups: [:])
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleMessage("cheatsheet-show:finder")
        let action = logic.handleLayerChange("apps")
        #expect(action == .hide)
    }

    // MARK: - Modifier-Space legend

    @Test("free-slot message toggles only while apps is visible")
    func togglesFreeSlotsForApps() {
        let logic = OverlayLogic(config: appsConfig)
        _ = logic.handleLayerChange("apps")
        _ = logic.delayExpired()
        #expect(logic.handleMessage("cheatsheet-space-toggle-free") == .refresh)
        #expect(logic.showFreeModifierSpace)
        #expect(logic.handleMessage("cheatsheet-space-toggle-free") == .refresh)
        #expect(!logic.showFreeModifierSpace)
    }

    @Test("leaving apps resets occupied-only mode")
    func leavingAppsResetsFreeSlots() {
        let logic = OverlayLogic(config: appsConfig)
        _ = logic.handleLayerChange("apps")
        _ = logic.delayExpired()
        _ = logic.handleMessage("cheatsheet-space-toggle-free")
        _ = logic.handleLayerChange("mine")
        #expect(!logic.showFreeModifierSpace)
    }

    @Test("free-slot message is ignored outside apps")
    func ignoresFreeSlotsOutsideApps() {
        let config = Config(layers: ["nav": Config.Layer(label: "NAV", groups: [:])])
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        _ = logic.delayExpired()
        #expect(logic.handleMessage("cheatsheet-space-toggle-free") == .none)
        #expect(!logic.showFreeModifierSpace)
    }

    @Test("toggling free modifier-space slots resizes the overlay both ways")
    @MainActor
    func togglingFreeSlotsResizesOverlayBothWays() throws {
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let config = Config(
            display: display,
            layers: ["apps": Config.Layer(label: "APPS", groups: [:])]
        )
        let registry = modifierSpaceRegistry(occupiedCount: 6)
        let controller = OverlayController(config: config, registryResult: .success(registry))

        controller.handleMessage("cheatsheet-show:apps")
        let panel = try #require(NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last)
        let occupiedFrame = panel.frame

        controller.handleMessage("cheatsheet-space-toggle-free")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        let expandedContentView = try #require(panel.contentView)
        let expandedHeight = expandedContentView.fittingSize.height
        #expect(panel.frame.height >= expandedHeight)
        #expect(abs(expandedContentView.frame.height - panel.frame.height) <= 1)

        controller.handleMessage("cheatsheet-space-toggle-free")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        let restoredContentView = try #require(panel.contentView)
        #expect(abs(panel.frame.height - occupiedFrame.height) <= 1)
        #expect(abs(panel.frame.midY - occupiedFrame.midY) <= 1)
        #expect(restoredContentView.frame.origin == .zero)
        #expect(abs(restoredContentView.frame.height - panel.frame.height) <= 1)
        #expect(restoredContentView.fittingSize.height <= panel.frame.height)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("visible grouped layers reuse the same panel")
    @MainActor
    func visibleGroupedLayersReusePanel() throws {
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let registry = modifierSpaceRegistry(occupiedCount: 6)
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(registry)
        )

        controller.handleMessage("cheatsheet-show:apps")
        let originalPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        let originalAlpha = originalPanel.alphaValue

        controller.handleLayerChange("apps-alt")
        let switchedPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )

        #expect(switchedPanel === originalPanel)
        #expect(switchedPanel.isVisible)
        #expect(switchedPanel.alphaValue == originalAlpha)
        let contentView = try #require(switchedPanel.contentView)
        #expect(contentView.fittingSize.height <= switchedPanel.frame.height)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("grouped layer change keeps the original delay deadline")
    @MainActor
    func groupedLayerChangeKeepsDelayDeadline() throws {
        let display = Config.Display(
            delay_ms: 300,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let registry = modifierSpaceRegistry(occupiedCount: 6)
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(registry)
        )

        controller.handleLayerChange("apps")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        controller.handleLayerChange("apps-alt")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.16))

        let visiblePanel = NSApplication.shared.windows
            .compactMap { $0 as? OverlayPanel }
            .last { $0.isVisible }
        #expect(visiblePanel != nil)

        controller.handleMessage("cheatsheet-hide")
    }

    private func modifierSpaceRegistry(occupiedCount: Int) -> KeybindingRegistry {
        let binding = RegistryBinding(
            id: "test.action",
            provider: "test",
            ownership: "observed",
            gesture: RegistryGesture(
                type: "chord",
                key: "Space",
                modifiers: ["command"],
                display: "Command Space",
                prefixKey: nil
            ),
            context: RegistryContext(
                stage: "system",
                application: nil,
                mode: nil,
                layer: nil,
                device: nil
            ),
            action: RegistryAction(id: "test.action", label: "Test action", detail: nil),
            source: RegistrySource(path: "test", target: nil, line: nil),
            tags: [],
            diagnosticIds: []
        )
        let slots = (0..<15).map { index in
            ModifierSpaceSlot(
                modifiers: ["modifier-\(index)"],
                display: "M\(index) Space",
                state: index < occupiedCount ? "occupied" : "free",
                bindingIds: index < occupiedCount ? [binding.id] : []
            )
        }
        return KeybindingRegistry(
            schemaVersion: 1,
            providers: [],
            bindings: [binding],
            diagnostics: [],
            views: RegistryViews(
                modifierSpace: ModifierSpaceView(
                    id: "modifier-space",
                    label: "Modifier + Space",
                    slots: slots
                ),
                allBindings: AllBindingsView(id: "all-bindings", label: "All Bindings", bindingIds: []),
                keyboardLayers: KeyboardLayersView(
                    id: "keyboard-layers",
                    label: "Keyboard Layers",
                    geometry: RegistryKeyboardGeometry(
                        layoutId: "mine-iso",
                        rows: [
                            [
                                RegistryKeyboardPosition(
                                    position: "KeyW",
                                    sourceKey: "w",
                                    mineKey: "L",
                                    namedKey: nil,
                                    width: 1
                                ),
                            ],
                        ]
                    ),
                    layers: [
                        "apps": RegistryKeyboardLayer(
                            id: "apps",
                            label: "Apps",
                            trigger: "delay",
                            overlayGroup: "apps",
                            groups: [],
                            cells: [:]
                        ),
                        "apps-alt": RegistryKeyboardLayer(
                            id: "apps-alt",
                            label: "Alternate Apps",
                            trigger: "delay",
                            overlayGroup: "apps",
                            groups: [],
                            cells: [:]
                        ),
                    ]
                )
            )
        )
    }
}
