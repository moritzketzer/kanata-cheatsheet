import Testing
import Foundation

@Suite("OverlayController Logic")
struct OverlayControllerTests {
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
}
