import Testing
import Foundation

@Suite("OverlayController Logic")
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
        let action = logic.delayExpired(for: "nav")
        #expect(action == .show("nav"))
    }

    @Test("delay expiry for stale layer does nothing")
    func staleDelayIgnored() {
        let config = Config(
            display: Config.Display(delay_ms: 100),
            layers: [
                "nav": Config.Layer(label: "NAV", groups: [:]),
                "apps": Config.Layer(label: "APPS", groups: [:])
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        _ = logic.handleLayerChange("apps")
        let action = logic.delayExpired(for: "nav")
        #expect(action == .none)
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
        _ = logic.delayExpired(for: "nav")
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
        _ = logic.delayExpired(for: "apps")
        #expect(logic.handleMessage("cheatsheet-space-toggle-free") == .refresh)
        #expect(logic.showFreeModifierSpace)
        #expect(logic.handleMessage("cheatsheet-space-toggle-free") == .refresh)
        #expect(!logic.showFreeModifierSpace)
    }

    @Test("leaving apps resets occupied-only mode")
    func leavingAppsResetsFreeSlots() {
        let logic = OverlayLogic(config: appsConfig)
        _ = logic.handleLayerChange("apps")
        _ = logic.delayExpired(for: "apps")
        _ = logic.handleMessage("cheatsheet-space-toggle-free")
        _ = logic.handleLayerChange("mine")
        #expect(!logic.showFreeModifierSpace)
    }

    @Test("free-slot message is ignored outside apps")
    func ignoresFreeSlotsOutsideApps() {
        let config = Config(layers: ["nav": Config.Layer(label: "NAV", groups: [:])])
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("nav")
        _ = logic.delayExpired(for: "nav")
        #expect(logic.handleMessage("cheatsheet-space-toggle-free") == .none)
        #expect(!logic.showFreeModifierSpace)
    }
}
