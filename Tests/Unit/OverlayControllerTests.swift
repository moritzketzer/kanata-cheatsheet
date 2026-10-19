import Testing
import Foundation
import AppKit
import SwiftUI

@Suite("OverlayController Logic", .serialized)
struct OverlayControllerTests {
    @Test("Pomodoro reads immediately and refreshes the same panel once per second")
    @MainActor
    func pomodoroRefreshPreservesPanel() throws {
        var reads = 0
        var status = try decodedPomodoroStatus()
        let controller = OverlayController(
            config: pomodoroConfig,
            registryResult: .failure(NSError(domain: "Test", code: 1)),
            pomodoroStatusReader: { reads += 1; return status },
            presentsPanels: false
        )
        #expect(reads == 0)
        controller.handleLayerChange("pomodoro")
        #expect(reads == 0)
        controller.handleMessage("cheatsheet-show")
        defer { controller.handleMessage("cheatsheet-hide") }

        let (panel, host) = try panelAndHost()
        let keyWindow = NSApplication.shared.keyWindow
        #expect(reads == 1)
        #expect(host.rootView.pomodoroStatus == status)
        #expect(!controller.isModifierTimerRunning)

        // Let AppKit settle its initial window constraints before the first timer tick.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        let frame = panel.frame

        status = try decodedPomodoroStatus(state: "running", remaining: 221)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.1))

        #expect(reads == 2)
        #expect(host.rootView.pomodoroStatus == status)
        #expect(panel === overlayPanels().last)
        #expect(panel.contentView === host)
        #expect(panel.frame == frame)
        #expect(NSApplication.shared.keyWindow === keyWindow)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }

    @Test("Pomodoro stops reading on hide and on replacement", arguments: [false, true])
    @MainActor
    func pomodoroStopsReading(replace: Bool) throws {
        var reads = 0
        let status = try decodedPomodoroStatus()
        let controller = OverlayController(
            config: pomodoroConfig,
            registryResult: .failure(NSError(domain: "Test", code: 1)),
            pomodoroStatusReader: { reads += 1; return status },
            presentsPanels: false
        )
        controller.handleMessage("cheatsheet-pin-toggle:pomodoro")
        #expect(reads == 1)

        if replace {
            controller.handleConnectionChange(true)
            controller.handleLayerChange("yabai")
            #expect(controller.isModifierTimerRunning)
        } else {
            controller.handleMessage("cheatsheet-hide")
        }
        defer { controller.handleMessage("cheatsheet-hide") }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.1))
        #expect(reads == 1)

        if replace {
            controller.handleLayerChange("pomodoro")
            #expect(reads == 2)
            #expect(!controller.isModifierTimerRunning)
        }
    }

    @Test("Pomodoro timer does not retain its controller or continue reading after deinit")
    @MainActor
    func pomodoroStopsReadingAfterDeinit() throws {
        var reads = 0
        var controller: OverlayController? = OverlayController(
            config: pomodoroConfig,
            registryResult: .failure(NSError(domain: "Test", code: 1)),
            pomodoroStatusReader: { reads += 1; return nil },
            presentsPanels: false
        )
        weak let weakController = controller
        controller?.handleMessage("cheatsheet-show:pomodoro")
        let panel = try currentPanel()
        defer { panel.orderOut(nil) }
        #expect(reads == 1)
        controller = nil

        #expect(weakController == nil)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.1))
        #expect(reads == 1)
    }

    @Test("missing Pomodoro data replaces previously displayed progress")
    @MainActor
    func pomodoroUnavailableReplacesProgress() throws {
        var status: PomodoroStatus? = try decodedPomodoroStatus()
        let controller = OverlayController(
            config: pomodoroConfig,
            registryResult: .failure(NSError(domain: "Test", code: 1)),
            pomodoroStatusReader: { status },
            presentsPanels: false
        )
        controller.handleMessage("cheatsheet-show:pomodoro")
        defer { controller.handleMessage("cheatsheet-hide") }
        let (panel, host) = try panelAndHost()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        let frame = panel.frame
        status = nil
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.1))

        #expect(host.rootView.pomodoroStatus == nil)
        #expect(panel.frame == frame)
        let header = PomodoroHeaderView(title: "Pomodoro", status: nil, width: 800)
        #expect(header.statusLine == "Timerstatus nicht verfügbar")
        #expect(header.progressLine == "Tagesziel Dissertation: 30 Minuten")
    }

    @Test("Pomodoro header keeps fitting size across all states and both geometries", arguments: ["macbook", "defy"])
    @MainActor
    func pomodoroHeaderKeepsFittingSize(profile: String) throws {
        let statuses: [PomodoroStatus?] = try [
            decodedPomodoroStatus(state: "idle", remaining: 1500),
            decodedPomodoroStatus(state: "running"),
            decodedPomodoroStatus(),
            decodedPomodoroStatus(state: "running", mode: "break"),
            decodedPomodoroStatus(state: "expired", remaining: -1),
            decodedPomodoroStatus(progress: 2461),
        ] + [nil]
        let sizes = statuses.map { status in
            NSHostingView(rootView: KeyboardView(
                layerName: "pomodoro",
                legacyLayer: nil,
                display: pomodoroConfig.display,
                registry: geometryProfileRegistry(includePomodoro: true),
                geometryProfileId: profile,
                pomodoroStatus: status
            )).fittingSize
        }
        #expect(sizes.allSatisfy { $0 == sizes[0] })
    }

    private var pomodoroConfig: Config {
        immediateConfig(layers: [
            "pomodoro": Config.Layer(label: "Pomodoro", trigger: "manual", groups: [:]),
            "yabai": Config.Layer(label: "Yabai", trigger: "manual", groups: [:]),
        ])
    }

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
        let (controller, _, host, _) = try shownYabaiController(flags: { 0x20 })

        #expect(host.rootView.presentation.key(at: "KeyU")?.actionModifier == .option)
        #expect(controller.isModifierTimerRunning)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("modifier refresh reuses the Yabai panel host and frame")
    @MainActor
    func modifierRefreshReusesPanelGeometry() throws {
        var flags: UInt = 0
        let (controller, panel, host, frame) = try shownYabaiController(
            flags: { flags }
        )

        flags = 0x8
        controller.sampleModifierFlags()

        #expect(panel === overlayPanels().last)
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
        let controller = OverlayController(
            config: immediateConfig(),
            registryResult: .success(yabaiRegistry()),
            modifierFlags: { flags },
            presentsPanels: false
        )
        controller.handleConnectionChange(true)
        controller.handleMessage("cheatsheet-show:yabai")
        let (panel, host) = try panelAndHost()
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
        let (controller, panel, host, frame) = try shownYabaiController(
            flags: { flags }
        )

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
        let controller = OverlayController(
            config: immediateConfig(delay_ms: 30),
            registryResult: .success(yabaiRegistry(
                trigger: "delay",
                includeApps: true
            )),
            modifierFlags: { 0x20 },
            presentsPanels: false
        )
        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))

        let (panel, host) = try panelAndHost()
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
        let (_, replacementHost) = try panelAndHost()
        #expect(replacementHost.rootView.presentation.name == "apps")

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("fresh delayed Yabai notification samples without a duplicate show")
    @MainActor
    func freshDelayedYabaiNotificationSamplesWithoutDuplicateShow() throws {
        var flags: UInt = 0
        let controller = OverlayController(
            config: immediateConfig(delay_ms: 30),
            registryResult: .success(yabaiRegistry(trigger: "delay")),
            modifierFlags: { flags },
            presentsPanels: false
        )
        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))

        let (panel, host) = try panelAndHost()
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
        let stillVisible = try currentPanel()
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
            defaults: defaults,
            presentsPanels: false
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
            let earlierPanels = overlayPanels()
            let suite = "AutomaticGeometryDelayTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let controller = OverlayController(
                config: immediateConfig(delay_ms: 30),
                registryResult: .success(geometryProfileRegistry(trigger: "delay")),
                defaults: defaults,
                presentsPanels: false
            )

            if selectionFirst {
                controller.handleMessage("cheatsheet-geometry-select:defy")
                controller.handleLayerChange("apps")
            } else {
                controller.handleLayerChange("apps")
                controller.handleMessage("cheatsheet-geometry-select:defy")
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))

            #expect(overlayPanel(newerThan: earlierPanels) != nil)
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
            defaults: defaults,
            presentsPanels: false
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
            defaults: defaults,
            presentsPanels: false
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
        let controller = OverlayController(
            config: immediateConfig(),
            registryResult: .success(geometryProfileRegistry()),
            defaults: defaults,
            presentsPanels: false
        )

        controller.handleMessage("cheatsheet-show:apps")
        let macbookPanel = try currentPanel()
        let macbookFrame = macbookPanel.frame

        controller.handleMessage("cheatsheet-geometry-toggle")
        let defyPanel = try currentPanel()

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
        let controller = OverlayController(
            config: immediateConfig(),
            registryResult: .success(geometryProfileRegistry()),
            defaults: defaults,
            presentsPanels: false
        )

        controller.handleMessage("cheatsheet-geometry-select:defy")
        controller.handleMessage("cheatsheet-pin-toggle:mine")
        let ordinaryPanel = try currentPanel()
        let ordinaryFrame = ordinaryPanel.frame

        controller.handleMessage("cheatsheet-input-path-toggle")
        let inputPathPanel = try currentPanel()

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
        let config = immediateConfig(
            layers: ["apps": Config.Layer(label: "APPS", groups: [:])]
        )
        let registry = modifierSpaceRegistry(occupiedCount: 6)
        let controller = OverlayController(
            config: config,
            registryResult: .success(registry),
            presentsPanels: false
        )

        controller.handleMessage("cheatsheet-show:apps")
        let panel = try currentPanel()
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
        let registry = modifierSpaceRegistry(occupiedCount: 6)
        let controller = OverlayController(
            config: immediateConfig(),
            registryResult: .success(registry),
            presentsPanels: false
        )

        controller.handleMessage("cheatsheet-show:apps")
        let originalPanel = try currentPanel()
        let originalAlpha = originalPanel.alphaValue

        controller.handleLayerChange("apps-alt")
        let switchedPanel = try currentPanel()

        #expect(switchedPanel === originalPanel)
        #expect(switchedPanel.alphaValue == originalAlpha)
        let contentView = try #require(switchedPanel.contentView)
        #expect(contentView.fittingSize.height <= switchedPanel.frame.height)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("grouped layer change keeps the original delay deadline")
    @MainActor
    func groupedLayerChangeKeepsDelayDeadline() throws {
        let registry = modifierSpaceRegistry(occupiedCount: 6)
        let earlierPanels = overlayPanels()
        let controller = OverlayController(
            config: immediateConfig(delay_ms: 300),
            registryResult: .success(registry),
            presentsPanels: false
        )

        controller.handleLayerChange("apps")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        controller.handleLayerChange("apps-alt")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.16))

        #expect(overlayPanel(newerThan: earlierPanels) != nil)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("pinned Mine and Fn render Defy rows in one fitted panel")
    @MainActor
    func pinnedMineFnCycleRendersDefyRows() throws {
        let display = immediateDisplay()
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
            registryResult: .success(pinnedLensRegistry()),
            presentsPanels: false
        )

        controller.handleMessage("cheatsheet-pin-toggle:mine")
        let minePanel = try currentPanel()
        controller.handleLayerChange("fn")
        let fnPanel = try currentPanel()
        #expect(fnPanel === minePanel)
        #expect(try #require(fnPanel.contentView).fittingSize.height <= fnPanel.frame.height)

        controller.handleLayerChange("mine")
        let restoredPanel = try currentPanel()
        #expect(restoredPanel === minePanel)
        #expect(try #require(restoredPanel.contentView).fittingSize.height <= restoredPanel.frame.height)

        controller.handleMessage("cheatsheet-hide")
    }

    @Test("headless controller never puts a panel on screen")
    @MainActor
    func headlessControllerKeepsPanelsOffScreen() throws {
        let display = Config.Display(
            delay_ms: 0,
            fade_in_ms: 150,
            fade_out_ms: 100,
            width_percent: 75
        )
        let earlierPanels = overlayPanels()
        let controller = OverlayController(
            config: Config(display: display, layers: [:]),
            registryResult: .success(modifierSpaceRegistry(occupiedCount: 6)),
            presentsPanels: false
        )

        controller.handleMessage("cheatsheet-show:apps")

        let panel = try #require(overlayPanel(newerThan: earlierPanels))
        #expect(panel.contentView is NSHostingView<KeyboardView>)
        #expect(!panel.isVisible)
        // The configured fades are skipped, not deferred: the opacity the
        // animation would have reached is already applied.
        #expect(panel.alphaValue == CGFloat(display.opacity))

        controller.handleMessage("cheatsheet-hide")

        #expect(!panel.isVisible)
        #expect(panel.alphaValue == 0)
    }

    /// Every overlay panel this process has built, oldest first. Retired
    /// panels stay in the window list, and headless controllers never order a
    /// panel front, so identity rather than `isVisible` tells a fresh overlay
    /// from an earlier one.
    @MainActor
    private func overlayPanels() -> [OverlayPanel] {
        NSApplication.shared.windows.compactMap { $0 as? OverlayPanel }
    }

    @MainActor
    private func overlayPanel(newerThan earlier: [OverlayPanel]) -> OverlayPanel? {
        let known = Set(earlier.map(ObjectIdentifier.init))
        return overlayPanels().last { !known.contains(ObjectIdentifier($0)) }
    }

    /// The overlay panel the controller under test built most recently.
    @MainActor
    private func currentPanel() throws -> OverlayPanel {
        try #require(overlayPanels().last)
    }

    @MainActor
    private func panelAndHost() throws -> (OverlayPanel, NSHostingView<KeyboardView>) {
        let panel = try currentPanel()
        return (
            panel,
            try #require(panel.contentView as? NSHostingView<KeyboardView>)
        )
    }

    /// Fade-free display geometry: panel tests read frames right after a show
    /// instead of waiting for an animation to settle.
    private func immediateDisplay(delay_ms: Int = 0) -> Config.Display {
        Config.Display(
            delay_ms: delay_ms,
            fade_in_ms: 0,
            fade_out_ms: 0,
            width_percent: 75
        )
    }

    private func immediateConfig(
        delay_ms: Int = 0,
        layers: [String: Config.Layer] = [:]
    ) -> Config {
        Config(display: immediateDisplay(delay_ms: delay_ms), layers: layers)
    }

    /// A headless controller whose live Yabai layer is already on a panel,
    /// together with that panel, its host, and the frame it settled on.
    @MainActor
    private func shownYabaiController(
        flags: @escaping () -> UInt
    ) throws -> (OverlayController, OverlayPanel, NSHostingView<KeyboardView>, NSRect) {
        let controller = OverlayController(
            config: immediateConfig(),
            registryResult: .success(yabaiRegistry()),
            modifierFlags: flags,
            presentsPanels: false
        )
        controller.handleConnectionChange(true)
        controller.handleLayerChange("yabai")
        controller.handleMessage("cheatsheet-show")
        let (panel, host) = try panelAndHost()
        return (controller, panel, host, panel.frame)
    }

    /// The schema-two shell every fixture below shares; only the geometry,
    /// layers, slots, and bindings differ per fixture.
    private func makeRegistry(
        geometry: RegistryKeyboardGeometry,
        layers: [String: RegistryKeyboardLayer],
        slots: [ModifierSpaceSlot] = [],
        bindings: [RegistryBinding] = []
    ) -> KeybindingRegistry {
        KeybindingRegistry(
            schemaVersion: 2,
            providers: [],
            bindings: bindings,
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
                    geometry: geometry,
                    layers: layers
                )
            )
        )
    }

    /// A layer that contributes nothing but its metadata: no groups, no cells.
    private func plainLayer(
        id: String,
        label: String,
        trigger: String,
        overlayGroup: String? = nil,
        showBaseKeys: Bool? = nil
    ) -> RegistryKeyboardLayer {
        RegistryKeyboardLayer(
            id: id,
            label: label,
            trigger: trigger,
            overlayGroup: overlayGroup,
            showBaseKeys: showBaseKeys,
            groups: [],
            cells: [:]
        )
    }

    private func namedPosition(
        _ name: String,
        _ source: String
    ) -> RegistryKeyboardPosition {
        RegistryKeyboardPosition(
            position: name,
            sourceKey: source,
            mineKey: nil,
            namedKey: name,
            width: 1
        )
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
        return makeRegistry(
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
                "apps": plainLayer(
                    id: "apps",
                    label: "Apps",
                    trigger: "delay",
                    overlayGroup: "apps"
                ),
                "apps-alt": plainLayer(
                    id: "apps-alt",
                    label: "Alternate Apps",
                    trigger: "delay",
                    overlayGroup: "apps"
                ),
            ],
            slots: slots,
            bindings: [binding]
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
        let defy = RegistryDefyThumbs(
            label: "Defy thumbs",
            left: RegistryDefyThumbSide(
                top: [
                    namedPosition("F13", "f13"), namedPosition("F14", "f14"),
                    namedPosition("F15", "f15"), namedPosition("F16", "f16"),
                ],
                bottom: [
                    namedPosition("Numpad0", "kp0"), namedPosition("Numpad1", "kp1"),
                    namedPosition("Numpad2", "kp2"), namedPosition("F17", "f17"),
                ]
            ),
            right: RegistryDefyThumbSide(
                top: [
                    namedPosition("F19", "f19"), namedPosition("F20", "f20"),
                    namedPosition("F21", "f21"), namedPosition("F22", "f22"),
                ],
                bottom: [
                    namedPosition("F18", "f18"), namedPosition("Numpad3", "kp3"),
                    namedPosition("Numpad4", "kp4"), namedPosition("Numpad5", "kp5"),
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
        return makeRegistry(
            geometry: RegistryKeyboardGeometry(
                layoutId: "mine-iso",
                rows: rows,
                defyThumbs: includeDefy ? defy : nil
            ),
            layers: [
                "mine": plainLayer(
                    id: "mine",
                    label: "Mine",
                    trigger: "manual",
                    showBaseKeys: true
                ),
                "fn": plainLayer(
                    id: "fn",
                    label: "Media · Brightness · F-Keys",
                    trigger: "manual"
                ),
            ],
            slots: freeSlots
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
            icon: RegistryKeyVisual(kind: "sf-symbol", token: "window.ceiling"),
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
            layers["apps"] = plainLayer(
                id: "apps",
                label: "Apps",
                trigger: "delay",
                showBaseKeys: true
            )
        }
        return makeRegistry(
            geometry: RegistryKeyboardGeometry(
                layoutId: "mine-iso",
                rows: [[position]]
            ),
            layers: layers
        )
    }

    private func geometryProfileRegistry(
        trigger: String = "manual",
        includeMine: Bool = true,
        includePomodoro: Bool = false
    ) -> KeybindingRegistry {
        let position = RegistryKeyboardPosition(
            position: "KeyO",
            sourceKey: "o",
            mineKey: "G",
            namedKey: nil,
            width: 1
        )
        let arrows = RegistryArrowCluster(
            up: namedPosition("ArrowUp", "up"),
            left: namedPosition("ArrowLeft", "left"),
            down: namedPosition("ArrowDown", "down"),
            right: namedPosition("ArrowRight", "right")
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
            "apps": plainLayer(id: "apps", label: "Apps", trigger: trigger),
            "fn": plainLayer(id: "fn", label: "Fn", trigger: "manual"),
        ]
        if includeMine {
            layers["mine"] = plainLayer(
                id: "mine",
                label: "Mine",
                trigger: "manual"
            )
        }
        if includePomodoro {
            layers["pomodoro"] = plainLayer(
                id: "pomodoro",
                label: "Pomodoro",
                trigger: "manual"
            )
        }
        return makeRegistry(geometry: geometry, layers: layers)
    }
}
