import Testing
import Foundation
import AppKit
import SwiftUI

@Suite("OverlayController Logic", .serialized)
struct OverlayControllerTests {
    private var appsConfig: Config {
        Config(
            display: Config.Display(delay_ms: 100),
            layers: ["apps": Config.Layer(label: "APPS", groups: [:])]
        )
    }

    private var yabaiConfig: Config {
        Config(
            display: Config.Display(delay_ms: 100),
            layers: [
                "yabai": Config.Layer(
                    label: "YABAI",
                    trigger: "manual",
                    groups: [:]
                ),
            ]
        )
    }

    @Test("connected live visible Yabai enables modifier sampling")
    func liveYabaiEnablesModifierSampling() {
        let logic = OverlayLogic(config: yabaiConfig)

        #expect(logic.handleConnectionChange(true) == .none)
        #expect(logic.handleLayerChange("yabai") == .none)
        #expect(!logic.samplesYabaiModifiers)
        #expect(logic.handleMessage("cheatsheet-show") == .show("yabai"))
        #expect(logic.samplesYabaiModifiers)
        #expect(logic.yabaiQualifier == nil)
    }

    @Test("hidden and delayed Yabai snapshots do not change presentation")
    func hiddenAndDelayedYabaiIgnoreModifierSnapshots() {
        let hidden = OverlayLogic(config: yabaiConfig)
        _ = hidden.handleConnectionChange(true)
        _ = hidden.handleLayerChange("yabai")

        #expect(hidden.handleModifierFlags(0x20) == .none)
        #expect(hidden.activeModifiers.isEmpty)

        let delayed = OverlayLogic(
            config: Config(
                layers: [
                    "yabai": Config.Layer(label: "YABAI", groups: [:]),
                ]
            )
        )
        _ = delayed.handleConnectionChange(true)
        #expect(delayed.handleLayerChange("yabai") == .startDelay("yabai"))
        #expect(delayed.handleModifierFlags(0x8) == .none)
        #expect(delayed.activeModifiers.isEmpty)
    }

    @Test("live Yabai refreshes only for changed modifier snapshots")
    func liveYabaiRefreshesChangedSnapshots() {
        let logic = OverlayLogic(config: yabaiConfig)
        _ = logic.handleConnectionChange(true)
        _ = logic.handleLayerChange("yabai")
        _ = logic.handleMessage("cheatsheet-show")

        #expect(logic.handleModifierFlags(0x20) == .refresh)
        #expect(logic.activeModifiers == [.option])
        #expect(logic.handleModifierFlags(0x20 | 0x2054) == .none)
        #expect(logic.activeModifiers == [.option])
        #expect(logic.handleModifierFlags(0) == .refresh)
        #expect(logic.activeModifiers.isEmpty)
    }

    @Test("Yabai hide layer exit and disconnect clear active roles")
    func YabaiLifecycleClearsActiveRoles() {
        let layerExit = liveYabaiLogic()
        _ = layerExit.handleModifierFlags(0x2)
        #expect(layerExit.handleLayerChange("mine") == .hide)
        #expect(layerExit.activeModifiers.isEmpty)
        #expect(!layerExit.samplesYabaiModifiers)

        let hidden = liveYabaiLogic()
        _ = hidden.handleModifierFlags(0x8)
        #expect(hidden.handleMessage("cheatsheet-hide") == .hide)
        #expect(hidden.activeModifiers.isEmpty)
        #expect(!hidden.samplesYabaiModifiers)

        let disconnected = liveYabaiLogic()
        _ = disconnected.handleModifierFlags(0x1)
        #expect(disconnected.handleConnectionChange(false) == .refresh)
        #expect(disconnected.activeModifiers.isEmpty)
        #expect(disconnected.currentLayer == nil)
        #expect(disconnected.yabaiQualifier == "Kanata disconnected")
        #expect(!disconnected.samplesYabaiModifiers)
    }

    @Test("reconnected Yabai waits for a fresh layer notification")
    func reconnectWaitsForFreshYabaiLayer() {
        let logic = liveYabaiLogic()
        _ = logic.handleModifierFlags(0x8)
        _ = logic.handleConnectionChange(false)

        #expect(logic.handleConnectionChange(true) == .refresh)
        #expect(logic.yabaiQualifier == "Preview")
        #expect(!logic.samplesYabaiModifiers)
        #expect(logic.handleModifierFlags(0x20) == .none)
        #expect(logic.activeModifiers.isEmpty)

        #expect(logic.handleLayerChange("yabai") == .refresh)
        #expect(logic.samplesYabaiModifiers)
        #expect(logic.handleModifierFlags(0x20) == .refresh)
        #expect(logic.activeModifiers == [.option])
    }

    @Test("controller samples Yabai before its first visible frame")
    @MainActor
    func controllerSamplesBeforeShowingYabai() throws {
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(yabaiRegistry()),
            modifierFlags: { 0x20 }
        )

        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        controller.handleMessage("cheatsheet-show")

        let panel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        let host = try #require(panel.contentView as? NSHostingView<KeyboardView>)
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == .option)
        #expect(controller.isModifierTimerRunning)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("modifier refresh reuses the Yabai panel host and frame")
    @MainActor
    func modifierRefreshReusesPanelGeometry() throws {
        var flags: UInt = 0
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(yabaiRegistry()),
            modifierFlags: { flags }
        )
        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        controller.handleMessage("cheatsheet-show")
        let panel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        let host = try #require(panel.contentView as? NSHostingView<KeyboardView>)
        let frame = panel.frame

        flags = 0x8
        controller.sampleModifierFlags()

        #expect(panel === NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last)
        #expect(panel.contentView === host)
        #expect(panel.frame == frame)
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == .command)

        controller.handleConnectionChange(false)
        #expect(!controller.isModifierTimerRunning)
        #expect(host.rootView.yabaiQualifier == "Kanata disconnected")
        controller.handleMessage("cheatsheet-hide")
    }

    @Test("visible Yabai preview samples before the fresh live layer refresh")
    @MainActor
    func previewToLiveSamplesBeforeRefresh() throws {
        let flags: UInt = 0x20
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(yabaiRegistry()),
            modifierFlags: { flags }
        )
        controller.handleConnectionChange(true)
        controller.handleMessage("cheatsheet-show:yabai")
        let panel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        let host = try #require(panel.contentView as? NSHostingView<KeyboardView>)
        let frame = panel.frame
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == nil)
        #expect(host.rootView.yabaiQualifier == "Preview")

        controller.handleLayerChange("yabai")

        #expect(panel.contentView === host)
        #expect(panel.frame == frame)
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == .option)
        #expect(host.rootView.yabaiQualifier == nil)
        #expect(controller.isModifierTimerRunning)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("reconnect samples before the fresh Yabai layer refresh")
    @MainActor
    func reconnectSamplesBeforeFreshLayerRefresh() throws {
        var flags: UInt = 0
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(yabaiRegistry()),
            modifierFlags: { flags }
        )
        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        controller.handleMessage("cheatsheet-show")
        let panel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        let host = try #require(panel.contentView as? NSHostingView<KeyboardView>)
        let frame = panel.frame

        controller.handleConnectionChange(false)
        controller.handleConnectionChange(true)
        flags = 0x8
        controller.handleLayerChange("yabai")

        #expect(panel.contentView === host)
        #expect(panel.frame == frame)
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == .command)
        #expect(host.rootView.yabaiQualifier == nil)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("delayed layer exit immediately reconciles visible Yabai")
    @MainActor
    func delayedLayerExitImmediatelyReconcilesVisibleYabai() throws {
        let display = Config.Display(
            delay_ms: 30,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(yabaiRegistry(
                trigger: "delay",
                includeApps: true
            )),
            modifierFlags: { 0x20 }
        )
        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))

        let panel = try #require(
            NSApplication.shared.windows
                .compactMap { $0 as? OverlayPanel }
                .last { $0.isVisible }
        )
        let host = try #require(panel.contentView as? NSHostingView<KeyboardView>)
        let frame = panel.frame
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == .option)
        #expect(host.rootView.yabaiQualifier == nil)

        controller.handleLayerChange("apps")

        #expect(panel.contentView === host)
        #expect(panel.frame == frame)
        #expect(host.rootView.presentation.name == "yabai")
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == nil)
        #expect(host.rootView.yabaiQualifier == "Preview")
        #expect(!controller.isModifierTimerRunning)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))
        let replacement = try #require(
            NSApplication.shared.windows
                .compactMap { $0 as? OverlayPanel }
                .last { $0.isVisible }
        )
        let replacementHost = try #require(
            replacement.contentView as? NSHostingView<KeyboardView>
        )
        #expect(replacementHost.rootView.presentation.name == "apps")

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("fresh delayed Yabai notification samples without a duplicate show")
    @MainActor
    func freshDelayedYabaiNotificationSamplesWithoutDuplicateShow() throws {
        var flags: UInt = 0
        let display = Config.Display(
            delay_ms: 30,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(yabaiRegistry(trigger: "delay")),
            modifierFlags: { flags }
        )
        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))

        let panel = try #require(
            NSApplication.shared.windows
                .compactMap { $0 as? OverlayPanel }
                .last { $0.isVisible }
        )
        let host = try #require(panel.contentView as? NSHostingView<KeyboardView>)
        let frame = panel.frame

        controller.handleConnectionChange(false)
        controller.handleConnectionChange(true)
        flags = 0x8
        controller.handleLayerChange("yabai")

        #expect(panel.contentView === host)
        #expect(panel.frame == frame)
        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == .command)
        #expect(host.rootView.yabaiQualifier == nil)
        #expect(controller.isModifierTimerRunning)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))
        let stillVisible = try #require(
            NSApplication.shared.windows
                .compactMap { $0 as? OverlayPanel }
                .last { $0.isVisible }
        )
        #expect(stillVisible === panel)
        #expect(stillVisible.contentView === host)
        #expect(stillVisible.frame == frame)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("Yabai fitting size is invariant across modifier states")
    @MainActor
    func YabaiModifierStatesKeepFittingSize() {
        let display = Config.Display(width_percent: 75)
        let registry = yabaiRegistry()
        let modifierStates: [Set<YabaiModifier>] = [
            [], [.option], [.shift], [.command], [.control], [.command, .shift],
        ]
        let sizes = modifierStates.map { modifiers -> NSSize in
            NSHostingView(rootView: KeyboardView(
                layerName: "yabai",
                legacyLayer: nil,
                display: display,
                registry: registry,
                showFreeModifierSpace: false,
                activeModifiers: modifiers,
                yabaiQualifier: "Preview"
            )).fittingSize
        }

        #expect(sizes.allSatisfy { $0 == sizes[0] })
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

    // MARK: - Pinned layer lens

    @Test("pin toggle anchors Mine even while Apps is current")
    func pinToggleAnchorsMine() {
        let config = Config(
            layers: [
                "apps": Config.Layer(label: "APPS", groups: [:]),
                "mine": Config.Layer(label: "MINE", trigger: "manual", groups: [:]),
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleLayerChange("apps")

        let action = logic.handleMessage("cheatsheet-pin-toggle:mine")

        #expect(action == .show("mine"))
        #expect(logic.pendingLayer == nil)
        #expect(logic.visibleLayer == "mine")
        #expect(logic.isVisible)
    }

    @Test("pinned lens replaces registered layers immediately")
    func pinnedLensReplacesRegisteredLayer() {
        let config = Config(
            layers: [
                "mine": Config.Layer(label: "MINE", trigger: "manual", groups: [:]),
                "fn": Config.Layer(label: "FN", trigger: "manual", groups: [:]),
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleMessage("cheatsheet-pin-toggle:mine")

        #expect(logic.handleLayerChange("fn") == .replace("fn"))
        #expect(logic.visibleLayer == "fn")
        #expect(logic.isPinned)
    }

    @Test("pinned lens keeps its presentation for unknown transient layers")
    func pinnedLensKeepsPresentationForUnknownLayer() {
        let config = Config(
            layers: [
                "mine": Config.Layer(label: "MINE", trigger: "manual", groups: [:]),
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleMessage("cheatsheet-pin-toggle:mine")

        #expect(logic.handleLayerChange("mine-plain") == .none)
        #expect(logic.visibleLayer == "mine")
        #expect(logic.isVisible)
        #expect(logic.isPinned)
    }

    @Test("pin toggle hides and clears pinned state on second invocation")
    func pinToggleTurnsOff() {
        let config = Config(
            layers: [
                "mine": Config.Layer(label: "MINE", trigger: "manual", groups: [:]),
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleMessage("cheatsheet-pin-toggle:mine")

        #expect(logic.handleMessage("cheatsheet-pin-toggle:mine") == .hide)
        #expect(!logic.isPinned)
        #expect(!logic.isVisible)
        #expect(logic.visibleLayer == nil)
    }

    @Test("hide message clears pinned state")
    func hideMessageClearsPinnedState() {
        let config = Config(
            layers: [
                "mine": Config.Layer(label: "MINE", trigger: "manual", groups: [:]),
            ]
        )
        let logic = OverlayLogic(config: config)
        _ = logic.handleMessage("cheatsheet-pin-toggle:mine")

        #expect(logic.handleMessage("cheatsheet-hide") == .hide)
        #expect(!logic.isPinned)
    }

    @Test("input path toggles while Apps is transient and survives Fn until Mine returns")
    func inputPathFollowsPinnedMine() {
        let logic = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )
        _ = logic.handleMessage("cheatsheet-geometry-select:defy")
        _ = logic.handleMessage("cheatsheet-pin-toggle:mine")
        #expect(logic.handleLayerChange("apps") == .replace("apps"))

        #expect(logic.handleMessage("cheatsheet-input-path-toggle") == .refresh)
        #expect(logic.showInputPath)
        #expect(!logic.showsInputPath(for: "apps"))

        #expect(logic.handleLayerChange("fn") == .replace("fn"))
        #expect(logic.showInputPath)
        #expect(!logic.showsInputPath(for: "fn"))

        #expect(logic.handleLayerChange("mine") == .replace("mine"))
        #expect(logic.showsInputPath(for: "mine"))
        #expect(logic.handleMessage("cheatsheet-input-path-toggle") == .refresh)
        #expect(!logic.showInputPath)
    }

    @Test("input path resets when the lens hides")
    func inputPathResetsOnHide() {
        let logic = activeInputPathLogic()

        #expect(logic.handleMessage("cheatsheet-hide") == .hide)
        #expect(!logic.showInputPath)
    }

    @Test("input path resets when the lens unpins")
    func inputPathResetsOnUnpin() {
        let logic = activeInputPathLogic()

        #expect(logic.handleMessage("cheatsheet-pin-toggle:mine") == .hide)
        #expect(!logic.showInputPath)
    }

    @Test("input path resets when geometry changes to MacBook")
    func inputPathResetsOnMacBook() {
        let logic = activeInputPathLogic()

        #expect(
            logic.handleMessage("cheatsheet-geometry-toggle")
                == .geometryChanged(
                    id: "macbook",
                    refreshVisibleOverlay: true,
                    persistSelection: true
                )
        )
        #expect(!logic.showInputPath)
    }

    @Test("input path ignores hidden, unpinned, MacBook, and missing Mine contexts")
    func inputPathRejectsInvalidContexts() {
        let hidden = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )
        _ = hidden.handleMessage("cheatsheet-geometry-select:defy")
        #expect(hidden.handleMessage("cheatsheet-input-path-toggle") == .none)

        let unpinned = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )
        _ = unpinned.handleMessage("cheatsheet-geometry-select:defy")
        _ = unpinned.handleMessage("cheatsheet-show:mine")
        #expect(unpinned.handleMessage("cheatsheet-input-path-toggle") == .none)

        let macbook = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )
        _ = macbook.handleMessage("cheatsheet-pin-toggle:mine")
        #expect(macbook.handleMessage("cheatsheet-input-path-toggle") == .none)

        let missingMine = OverlayLogic(
            config: Config(
                layers: [
                    "mine": Config.Layer(
                        label: "Mine",
                        trigger: "manual",
                        groups: [:]
                    ),
                ]
            ),
            registry: geometryProfileRegistry(includeMine: false)
        )
        _ = missingMine.handleMessage("cheatsheet-geometry-select:defy")
        _ = missingMine.handleMessage("cheatsheet-pin-toggle:mine")
        #expect(missingMine.isPinned)
        #expect(missingMine.handleMessage("cheatsheet-input-path-toggle") == .none)
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

    @Test("hidden geometry toggle changes only the selected profile")
    func hiddenGeometryTogglePreservesOverlayState() {
        let logic = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )

        #expect(logic.selectedGeometryProfileId == "macbook")
        #expect(
            logic.handleMessage("cheatsheet-geometry-toggle")
                == .geometryChanged(
                    id: "defy",
                    refreshVisibleOverlay: false,
                    persistSelection: true
                )
        )
        #expect(logic.selectedGeometryProfileId == "defy")
        #expect(!logic.isVisible)
        #expect(!logic.isPinned)
        #expect(logic.currentLayer == nil)
        #expect(logic.visibleLayer == nil)
        #expect(!logic.showFreeModifierSpace)
    }

    @Test("visible pinned geometry toggle preserves layer pin and free-slot state")
    func visiblePinnedGeometryTogglePreservesState() {
        let logic = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )
        _ = logic.handleLayerChange("apps")
        _ = logic.handleMessage("cheatsheet-show:apps")
        _ = logic.handleMessage("cheatsheet-space-toggle-free")
        _ = logic.handleMessage("cheatsheet-pin-toggle:apps")

        #expect(
            logic.handleMessage("cheatsheet-geometry-toggle")
                == .geometryChanged(
                    id: "defy",
                    refreshVisibleOverlay: true,
                    persistSelection: true
                )
        )
        #expect(logic.currentLayer == "apps")
        #expect(logic.visibleLayer == "apps")
        #expect(logic.isVisible)
        #expect(logic.isPinned)
        #expect(logic.showFreeModifierSpace)
    }

    @Test("automatic selection changes only runtime geometry")
    func automaticSelectionChangesOnlyRuntimeGeometry() {
        let logic = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )

        #expect(
            logic.handleMessage("cheatsheet-geometry-select:defy")
                == .geometryChanged(
                    id: "defy",
                    refreshVisibleOverlay: false,
                    persistSelection: false
                )
        )
        #expect(logic.selectedGeometryProfileId == "defy")
        #expect(logic.handleMessage("cheatsheet-geometry-select:defy") == .none)
        #expect(logic.handleMessage("cheatsheet-geometry-select:missing") == .none)
        #expect(!logic.isVisible)
        #expect(!logic.isPinned)
    }

    @Test("automatic selection preserves a visible pinned overlay")
    func automaticSelectionPreservesPinnedOverlay() {
        let logic = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )
        _ = logic.handleLayerChange("apps")
        _ = logic.handleMessage("cheatsheet-show:apps")
        _ = logic.handleMessage("cheatsheet-space-toggle-free")
        _ = logic.handleMessage("cheatsheet-pin-toggle:apps")

        #expect(
            logic.handleMessage("cheatsheet-geometry-select:defy")
                == .geometryChanged(
                    id: "defy",
                    refreshVisibleOverlay: true,
                    persistSelection: false
                )
        )
        #expect(logic.currentLayer == "apps")
        #expect(logic.visibleLayer == "apps")
        #expect(logic.isVisible)
        #expect(logic.isPinned)
        #expect(logic.showFreeModifierSpace)
    }

    @Test("controller does not persist automatic geometry selection")
    @MainActor
    func controllerDoesNotPersistAutomaticGeometrySelection() throws {
        let suite = "AutomaticGeometrySelectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(
            "macbook",
            forKey: KeyboardGeometrySelection.defaultsKey
        )
        let controller = OverlayController(
            config: Config(layers: [:]),
            registryResult: .success(geometryProfileRegistry()),
            defaults: defaults
        )

        controller.handleMessage("cheatsheet-geometry-select:defy")

        #expect(
            defaults.string(forKey: KeyboardGeometrySelection.defaultsKey)
                == "macbook"
        )
    }

    @Test("automatic selection preserves the overlay delay in either event order")
    @MainActor
    func automaticSelectionPreservesDelayInEitherOrder() throws {
        for selectionFirst in [true, false] {
            NSApplication.shared.windows
                .compactMap { $0 as? OverlayPanel }
                .forEach { $0.orderOut(nil) }
            let suite = "AutomaticGeometryDelayTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let controller = OverlayController(
                config: Config(
                    display: Config.Display(
                        delay_ms: 30,
                        fade_in_ms: 0,
                        fade_out_ms: 0,
                        width_percent: 75
                    ),
                    layers: [:]
                ),
                registryResult: .success(geometryProfileRegistry(trigger: "delay")),
                defaults: defaults
            )

            if selectionFirst {
                controller.handleMessage("cheatsheet-geometry-select:defy")
                controller.handleLayerChange("apps")
            } else {
                controller.handleLayerChange("apps")
                controller.handleMessage("cheatsheet-geometry-select:defy")
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))

            let visiblePanel = NSApplication.shared.windows
                .compactMap { $0 as? OverlayPanel }
                .last { $0.isVisible }
            #expect(visiblePanel != nil)
            controller.handleMessage("cheatsheet-hide")
        }
    }

    @Test("controller persists default repairs and restart selection")
    @MainActor
    func controllerPersistsGeometrySelection() throws {
        let suite = "KeyboardGeometrySelectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(
            "removed-profile",
            forKey: KeyboardGeometrySelection.defaultsKey
        )

        let first = OverlayController(
            config: Config(layers: [:]),
            registryResult: .success(geometryProfileRegistry()),
            defaults: defaults
        )
        #expect(
            defaults.string(forKey: KeyboardGeometrySelection.defaultsKey)
                == "macbook"
        )

        first.handleMessage("cheatsheet-geometry-toggle")
        #expect(
            defaults.string(forKey: KeyboardGeometrySelection.defaultsKey)
                == "defy"
        )

        let restored = OverlayController(
            config: Config(layers: [:]),
            registryResult: .success(geometryProfileRegistry()),
            defaults: defaults
        )
        restored.handleMessage("cheatsheet-geometry-toggle")
        #expect(
            defaults.string(forKey: KeyboardGeometrySelection.defaultsKey)
                == "macbook"
        )
    }

    @Test("visible geometry toggle refits the same panel")
    @MainActor
    func visibleGeometryToggleRefitsSamePanel() throws {
        let suite = "KeyboardGeometryLayoutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(geometryProfileRegistry()),
            defaults: defaults
        )

        controller.handleMessage("cheatsheet-show:apps")
        let macbookPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        let macbookFrame = macbookPanel.frame

        controller.handleMessage("cheatsheet-geometry-toggle")
        let defyPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )

        #expect(defyPanel === macbookPanel)
        #expect(defyPanel.frame.height > macbookFrame.height)
        #expect(try #require(defyPanel.contentView).fittingSize.width <= defyPanel.frame.width)
        #expect(defyPanel.styleMask.contains(.nonactivatingPanel))

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("input path refits the same non-activating panel")
    @MainActor
    func inputPathRefitsSamePanel() throws {
        let suite = "InputPathPanelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(geometryProfileRegistry()),
            defaults: defaults
        )

        controller.handleMessage("cheatsheet-geometry-select:defy")
        controller.handleMessage("cheatsheet-pin-toggle:mine")
        let ordinaryPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        let ordinaryFrame = ordinaryPanel.frame

        controller.handleMessage("cheatsheet-input-path-toggle")
        let inputPathPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )

        #expect(inputPathPanel === ordinaryPanel)
        #expect(inputPathPanel.frame.height > ordinaryFrame.height)
        #expect(inputPathPanel.styleMask.contains(.nonactivatingPanel))
        #expect(
            try #require(inputPathPanel.contentView).fittingSize.height
                <= inputPathPanel.frame.height
        )

        controller.handleMessage("cheatsheet-hide")
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

    @Test("pinned Mine and Fn render Defy rows in one fitted panel")
    @MainActor
    func pinnedMineFnCycleRendersDefyRows() throws {
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
        let baseView = NSHostingView(rootView: KeyboardView(
            layerName: "mine",
            legacyLayer: nil,
            display: display,
            registry: pinnedLensRegistry(includeDefy: false)
        ))
        let defyView = NSHostingView(rootView: KeyboardView(
            layerName: "mine",
            legacyLayer: nil,
            display: display,
            registry: pinnedLensRegistry()
        ))
        #expect(defyView.fittingSize.height > baseView.fittingSize.height)

        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(pinnedLensRegistry())
        )

        controller.handleMessage("cheatsheet-pin-toggle:mine")
        let minePanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        controller.handleLayerChange("fn")
        let fnPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        #expect(fnPanel === minePanel)
        #expect(try #require(fnPanel.contentView).fittingSize.height <= fnPanel.frame.height)

        controller.handleLayerChange("mine")
        let restoredPanel = try #require(
            NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }.last
        )
        #expect(restoredPanel === minePanel)
        #expect(try #require(restoredPanel.contentView).fittingSize.height <= restoredPanel.frame.height)

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
            schemaVersion: 2,
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

    private func pinnedLensRegistry(includeDefy: Bool = true) -> KeybindingRegistry {
        let rows = (0..<5).map { row in
            (0..<14).map { column in
                RegistryKeyboardPosition(
                    position: "Main\(row)-\(column)",
                    sourceKey: "main\(row)-\(column)",
                    mineKey: "K\(row)-\(column)",
                    namedKey: nil,
                    width: 1
                )
            }
        }
        let position = { (name: String, source: String) in
            RegistryKeyboardPosition(
                position: name,
                sourceKey: source,
                mineKey: nil,
                namedKey: name,
                width: 1
            )
        }
        let defy = RegistryDefyThumbs(
            label: "Defy thumbs",
            left: RegistryDefyThumbSide(
                top: [
                    position("F13", "f13"), position("F14", "f14"),
                    position("F15", "f15"), position("F16", "f16"),
                ],
                bottom: [
                    position("Numpad0", "kp0"), position("Numpad1", "kp1"),
                    position("Numpad2", "kp2"), position("F17", "f17"),
                ]
            ),
            right: RegistryDefyThumbSide(
                top: [
                    position("F19", "f19"), position("F20", "f20"),
                    position("F21", "f21"), position("F22", "f22"),
                ],
                bottom: [
                    position("F18", "f18"), position("Numpad3", "kp3"),
                    position("Numpad4", "kp4"), position("Numpad5", "kp5"),
                ]
            )
        )
        let freeSlots = (0..<15).map { index in
            ModifierSpaceSlot(
                modifiers: [],
                display: "slot-\(index)",
                state: "free",
                bindingIds: []
            )
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
                    slots: freeSlots
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
                        rows: rows,
                        defyThumbs: includeDefy ? defy : nil
                    ),
                    layers: [
                        "mine": RegistryKeyboardLayer(
                            id: "mine",
                            label: "Mine",
                            trigger: "manual",
                            overlayGroup: nil,
                            showBaseKeys: true,
                            groups: [],
                            cells: [:]
                        ),
                        "fn": RegistryKeyboardLayer(
                            id: "fn",
                            label: "Media · Brightness · F-Keys",
                            trigger: "manual",
                            overlayGroup: nil,
                            groups: [],
                            cells: [:]
                        ),
                    ]
                )
            )
        )
    }

    private func activeInputPathLogic() -> OverlayLogic {
        let logic = OverlayLogic(
            config: Config(layers: [:]),
            registry: geometryProfileRegistry()
        )
        _ = logic.handleMessage("cheatsheet-geometry-select:defy")
        _ = logic.handleMessage("cheatsheet-pin-toggle:mine")
        _ = logic.handleMessage("cheatsheet-input-path-toggle")
        return logic
    }

    private func liveYabaiLogic() -> OverlayLogic {
        let logic = OverlayLogic(config: yabaiConfig)
        _ = logic.handleConnectionChange(true)
        _ = logic.handleLayerChange("yabai")
        _ = logic.handleMessage("cheatsheet-show")
        return logic
    }

    private func yabaiRegistry(
        trigger: String = "manual",
        includeApps: Bool = false
    ) -> KeybindingRegistry {
        let position = RegistryKeyboardPosition(
            position: "KeyU",
            sourceKey: "u",
            mineKey: "U",
            namedKey: nil,
            width: 1
        )
        let presentation = RegistryKeyPresentation(
            primary: RegistryKeyVisual(kind: "sf-symbol", token: "window.ceiling"),
            holdModifier: "option",
            explanation: "Next window",
            modifierVariants: [
                RegistryModifierVariant(
                    modifier: .option,
                    primary: RegistryKeyVisual(
                        kind: "sf-symbol",
                        token: "square.stack.3d.up"
                    ),
                    explanation: "Stack next"
                ),
                RegistryModifierVariant(
                    modifier: .command,
                    primary: RegistryKeyVisual(
                        kind: "sf-symbol",
                        token: "arrow.up.to.line.square"
                    ),
                    explanation: "Warp north"
                ),
            ]
        )
        let cell = RegistryKeyboardCell(
            bindingId: "test.yabai.next-window",
            displayKey: "U",
            sourceKey: "u",
            actionLabel: "Focused app next window",
            group: "windows",
            icon: RegistryKeyIcon(kind: "sf-symbol", token: "window.ceiling"),
            presentation: presentation
        )
        var layers = [
            "yabai": RegistryKeyboardLayer(
                id: "yabai",
                label: "Yabai",
                trigger: trigger,
                overlayGroup: nil,
                showBaseKeys: true,
                groups: [
                    RegistryKeyboardGroup(
                        id: "windows",
                        color: "#cba6f7"
                    ),
                ],
                cells: ["KeyU": cell]
            ),
        ]
        if includeApps {
            layers["apps"] = RegistryKeyboardLayer(
                id: "apps",
                label: "Apps",
                trigger: "delay",
                overlayGroup: nil,
                showBaseKeys: true,
                groups: [],
                cells: [:]
            )
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
                    slots: []
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
                        rows: [[position]]
                    ),
                    layers: layers
                )
            )
        )
    }

    private func geometryProfileRegistry(
        trigger: String = "manual",
        includeMine: Bool = true
    ) -> KeybindingRegistry {
        let position = RegistryKeyboardPosition(
            position: "KeyO",
            sourceKey: "o",
            mineKey: "G",
            namedKey: nil,
            width: 1
        )
        let arrow = { (name: String, source: String) in
            RegistryKeyboardPosition(
                position: name,
                sourceKey: source,
                mineKey: nil,
                namedKey: name,
                width: 1
            )
        }
        let arrows = RegistryArrowCluster(
            up: arrow("ArrowUp", "up"),
            left: arrow("ArrowLeft", "left"),
            down: arrow("ArrowDown", "down"),
            right: arrow("ArrowRight", "right")
        )
        let defySlot = RegistryDefySlot(
            firmwareKey: "O",
            position: position
        )
        let defyHalf = RegistryDefyHalf(
            rows: [7, 7, 7, 7].map { count in
                Array(repeating: Optional(defySlot), count: count)
            },
            thumbs: RegistryDefyThumbRows(
                top: Array(repeating: Optional(defySlot), count: 4),
                bottom: Array(repeating: Optional(defySlot), count: 4)
            )
        )
        let geometry = RegistryKeyboardGeometry(
            layoutId: "mine-iso",
            rows: [[position]],
            arrowCluster: arrows,
            defaultProfileId: "macbook",
            profiles: [
                RegistryKeyboardGeometryProfile(
                    id: "macbook",
                    label: "MacBook",
                    kind: "macbook",
                    rows: [[position]],
                    arrowCluster: arrows
                ),
                RegistryKeyboardGeometryProfile(
                    id: "defy",
                    label: "Dygma Defy",
                    kind: "defy",
                    halves: RegistryDefyHalves(
                        left: defyHalf,
                        right: defyHalf
                    )
                ),
            ]
        )
        var layers: [String: RegistryKeyboardLayer] = [
            "apps": RegistryKeyboardLayer(
                id: "apps",
                label: "Apps",
                trigger: trigger,
                overlayGroup: nil,
                groups: [],
                cells: [:]
            ),
            "fn": RegistryKeyboardLayer(
                id: "fn",
                label: "Fn",
                trigger: "manual",
                overlayGroup: nil,
                groups: [],
                cells: [:]
            ),
        ]
        if includeMine {
            layers["mine"] = RegistryKeyboardLayer(
                id: "mine",
                label: "Mine",
                trigger: "manual",
                overlayGroup: nil,
                groups: [],
                cells: [:]
            )
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
                    slots: []
                ),
                allBindings: AllBindingsView(
                    id: "all-bindings",
                    label: "All Bindings",
                    bindingIds: []
                ),
                keyboardLayers: KeyboardLayersView(
                    id: "keyboard-layers",
                    label: "Keyboard Layers",
                    geometry: geometry,
                    layers: layers
                )
            )
        )
    }
}
