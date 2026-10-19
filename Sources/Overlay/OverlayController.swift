import AppKit
import SwiftUI

// MARK: - Pure logic (testable, no UI)

enum OverlayAction: Equatable {
    case startDelay(String)
    case retargetDelay(String)
    case show(String)
    case replace(String)
    case hide
    case refresh
    case geometryChanged(
        id: String,
        refreshVisibleOverlay: Bool,
        persistSelection: Bool
    )
    case none
}

/// Layer names the overlay special-cases. `KeyboardLayerPresentation` owns the
/// registry-facing spelling of Yabai and Pomodoro; `apps` and `mine` are only
/// meaningful to the behaviour in this file.
private enum LayerName {
    static let yabai = KeyboardLayerPresentation.yabaiLayerName
    static let pomodoro = KeyboardLayerPresentation.pomodoroLayerName
    static let apps = "apps"
    static let mine = "mine"
}

/// Overlay control messages kanata pushes through `push-msg`. The three
/// `…Prefix` names carry an argument; the rest are exact messages.
private enum OverlayMessage {
    static let geometrySelectPrefix = "cheatsheet-geometry-select:"
    static let pinTogglePrefix = "cheatsheet-pin-toggle:"
    static let showPrefix = "cheatsheet-show:"
    static let geometryToggle = "cheatsheet-geometry-toggle"
    static let spaceToggleFree = "cheatsheet-space-toggle-free"
    static let inputPathToggle = "cheatsheet-input-path-toggle"
    static let show = "cheatsheet-show"
    static let hide = "cheatsheet-hide"
    static let toggle = "cheatsheet-toggle"
}

/// The argument carried after `prefix`, or `nil` when `message` does not use
/// that prefix.
private func payload(of prefix: String, in message: String) -> Substring? {
    guard message.hasPrefix(prefix) else { return nil }
    return message.dropFirst(prefix.count)
}

final class OverlayLogic {
    private let layerTriggers: [String: String]
    private let registryOverlayGroups: [String: String]
    private let defyGeometryProfileIds: Set<String>
    private let hasMineLayerMetadata: Bool
    private var geometrySelection: KeyboardGeometrySelection
    private(set) var pendingLayer: String?
    private(set) var currentLayer: String?
    private(set) var visibleLayer: String?
    private(set) var isVisible = false
    private(set) var isPinned = false
    private(set) var showFreeModifierSpace = false
    private(set) var showInputPath = false
    private(set) var isConnected = false
    private(set) var activeModifiers: Set<YabaiModifier> = []

    var samplesYabaiModifiers: Bool {
        isConnected
            && currentLayer == LayerName.yabai
            && visibleLayer == LayerName.yabai
            && isVisible
    }

    var yabaiQualifier: String? {
        guard isVisible, visibleLayer == LayerName.yabai else { return nil }
        guard isConnected else { return "Kanata disconnected" }
        return currentLayer == LayerName.yabai ? nil : "Preview"
    }

    var selectedGeometryProfileId: String? {
        geometrySelection.selectedProfileId
    }

    init(
        config: Config,
        registry: KeybindingRegistry? = nil,
        storedGeometryProfileId: String? = nil
    ) {
        let keyboardLayers = registry?.views.keyboardLayers
        // Wherever the registry and the legacy config both describe a layer,
        // the registry's trigger wins.
        self.layerTriggers = config.layers
            .mapValues(\.trigger)
            .merging(keyboardLayers?.layers.mapValues(\.trigger) ?? [:]) { _, fromRegistry in
                fromRegistry
            }
        self.registryOverlayGroups = keyboardLayers?.layers.compactMapValues(\.overlayGroup) ?? [:]
        self.defyGeometryProfileIds = Set(
            keyboardLayers?.geometry?.effectiveProfiles
                .filter { $0.kind == "defy" }
                .map(\.id)
                ?? []
        )
        self.hasMineLayerMetadata = keyboardLayers?.layers[LayerName.mine] != nil
        self.geometrySelection = KeyboardGeometrySelection(
            geometry: keyboardLayers?.geometry,
            storedProfileId: storedGeometryProfileId
        )
    }

    private func trigger(for layer: String) -> String? {
        layerTriggers[layer]
    }

    private func hasLayer(_ layer: String) -> Bool {
        trigger(for: layer) != nil
    }

    private func sharesOverlayGroup(_ first: String?, _ second: String) -> Bool {
        guard
            let first,
            let firstGroup = registryOverlayGroups[first],
            let secondGroup = registryOverlayGroups[second]
        else { return false }
        return firstGroup == secondGroup
    }

    func showsInputPath(for layer: String) -> Bool {
        showInputPath && layer == LayerName.mine
    }

    /// The input path only exists on the Defy geometries, so it is the selected
    /// profile that decides whether it can be shown at all.
    private var isDefyProfileSelected: Bool {
        guard let selectedGeometryProfileId else { return false }
        return defyGeometryProfileIds.contains(selectedGeometryProfileId)
    }

    private func resetInputPathOutsideDefy() {
        if !isDefyProfileSelected {
            showInputPath = false
        }
    }

    /// Collapses the overlay together with every flag that only applies while
    /// it is on screen. Pinning is deliberately left alone: only the messages
    /// that unpin clear it.
    @discardableResult
    private func resetToHidden() -> OverlayAction {
        isVisible = false
        visibleLayer = nil
        showFreeModifierSpace = false
        showInputPath = false
        return .hide
    }

    /// Shows `layer` right away, dropping any layer still waiting for the
    /// reveal delay.
    private func presentImmediately(_ layer: String) -> OverlayAction {
        pendingLayer = nil
        isVisible = true
        visibleLayer = layer
        return .show(layer)
    }

    func handleLayerChange(_ layer: String) -> OverlayAction {
        finalizingYabaiState { updateLayer(layer) }
    }

    private func updateLayer(_ layer: String) -> OverlayAction {
        currentLayer = layer
        if layer != LayerName.apps {
            showFreeModifierSpace = false
        }
        if isPinned {
            return handleWhilePinned(layer)
        }
        guard let trigger = trigger(for: layer) else {
            pendingLayer = nil
            return resetToHidden()
        }
        if trigger == Config.Layer.manualTrigger {
            return handleManualTrigger(layer)
        }
        return handleAutomaticTrigger(layer)
    }

    /// An automatically triggered layer normally waits out the reveal delay.
    /// It skips that wait where the overlay already shows the layer, or shows
    /// one from the same overlay group, and it inherits a pending layer's
    /// deadline when both belong to one group.
    private func handleAutomaticTrigger(_ layer: String) -> OverlayAction {
        if layer == LayerName.yabai, isVisible, visibleLayer == layer {
            pendingLayer = nil
            return .none
        }
        if isVisible, sharesOverlayGroup(visibleLayer, layer) {
            pendingLayer = nil
            visibleLayer = layer
            return .replace(layer)
        }
        if sharesOverlayGroup(pendingLayer, layer) {
            pendingLayer = layer
            return .retargetDelay(layer)
        }
        pendingLayer = layer
        return .startDelay(layer)
    }

    /// A pinned overlay follows the live layer instead of hiding, as long as
    /// that layer has something to show.
    private func handleWhilePinned(_ layer: String) -> OverlayAction {
        pendingLayer = nil
        guard hasLayer(layer), visibleLayer != layer else { return .none }
        if isVisible {
            visibleLayer = layer
            return .replace(layer)
        }
        return presentImmediately(layer)
    }

    /// Manual layers only appear through an explicit `cheatsheet-*` message, so
    /// a layer change can merely retire a *different* visible layer.
    private func handleManualTrigger(_ layer: String) -> OverlayAction {
        pendingLayer = nil
        // A LayerChange to the same layer we're showing is the kanata multi
        // (push-msg + layer-switch) landing — keep it visible.
        guard isVisible, visibleLayer != layer else { return .none }
        return resetToHidden()
    }

    func delayExpired() -> OverlayAction {
        guard let pendingLayer else { return .none }
        return presentImmediately(pendingLayer)
    }

    func handleMessage(_ message: String) -> OverlayAction {
        finalizingYabaiState { updateMessage(message) }
    }

    private func updateMessage(_ message: String) -> OverlayAction {
        if let id = payload(of: OverlayMessage.geometrySelectPrefix, in: message) {
            return selectGeometry(id: String(id))
        }
        if let layer = payload(of: OverlayMessage.pinTogglePrefix, in: message) {
            return togglePin(layer: String(layer))
        }
        if let layer = payload(of: OverlayMessage.showPrefix, in: message) {
            return showLayer(String(layer))
        }
        switch message {
        case OverlayMessage.geometryToggle:
            return toggleGeometry()
        case OverlayMessage.spaceToggleFree:
            return toggleFreeModifierSpace()
        case OverlayMessage.inputPathToggle:
            return toggleInputPath()
        case OverlayMessage.show:
            return showCurrentLayer()
        case OverlayMessage.hide:
            return unpinAndHide()
        case OverlayMessage.toggle:
            return toggleCurrentLayer()
        default:
            return .none
        }
    }

    private func selectGeometry(id: String) -> OverlayAction {
        guard let selected = geometrySelection.select(id) else { return .none }
        resetInputPathOutsideDefy()
        return .geometryChanged(
            id: selected,
            refreshVisibleOverlay: isVisible,
            persistSelection: false
        )
    }

    private func toggleGeometry() -> OverlayAction {
        guard let id = geometrySelection.toggle() else { return .none }
        resetInputPathOutsideDefy()
        return .geometryChanged(
            id: id,
            refreshVisibleOverlay: isVisible,
            persistSelection: true
        )
    }

    private func togglePin(layer: String) -> OverlayAction {
        if isPinned {
            isPinned = false
            pendingLayer = nil
            return resetToHidden()
        }
        guard hasLayer(layer) else { return .none }
        isPinned = true
        showInputPath = false
        return presentImmediately(layer)
    }

    private func showLayer(_ layer: String) -> OverlayAction {
        guard hasLayer(layer) else { return .none }
        if layer != LayerName.apps {
            showFreeModifierSpace = false
        }
        return presentImmediately(layer)
    }

    private func showCurrentLayer() -> OverlayAction {
        guard let currentLayer, hasLayer(currentLayer) else { return .none }
        return presentImmediately(currentLayer)
    }

    private func toggleCurrentLayer() -> OverlayAction {
        guard isVisible else { return showCurrentLayer() }
        pendingLayer = nil
        return resetToHidden()
    }

    private func unpinAndHide() -> OverlayAction {
        let wasVisible = isVisible
        pendingLayer = nil
        isPinned = false
        resetToHidden()
        return wasVisible ? .hide : .none
    }

    private func toggleFreeModifierSpace() -> OverlayAction {
        guard isVisible, visibleLayer == LayerName.apps else { return .none }
        showFreeModifierSpace.toggle()
        return .refresh
    }

    private func toggleInputPath() -> OverlayAction {
        guard isVisible,
              isPinned,
              hasMineLayerMetadata,
              isDefyProfileSelected
        else { return .none }
        showInputPath.toggle()
        return .refresh
    }

    func handleConnectionChange(_ connected: Bool) -> OverlayAction {
        finalizingYabaiState {
            isConnected = connected
            if !connected {
                currentLayer = nil
            }
            return .none
        }
    }

    func handleModifierFlags(_ flags: UInt) -> OverlayAction {
        guard samplesYabaiModifiers else { return .none }
        let modifiers = YabaiModifier.active(in: flags)
        guard modifiers != activeModifiers else { return .none }
        activeModifiers = modifiers
        return .refresh
    }

    /// Runs `update` between a snapshot of the Yabai-facing presentation and
    /// `finalizeYabaiState`, which is what turns a silent presentation change
    /// into a repaint.
    private func finalizingYabaiState(_ update: () -> OverlayAction) -> OverlayAction {
        let previousQualifier = yabaiQualifier
        let previousModifiers = activeModifiers
        return finalizeYabaiState(
            update(),
            previousQualifier: previousQualifier,
            previousModifiers: previousModifiers
        )
    }

    private func finalizeYabaiState(
        _ action: OverlayAction,
        previousQualifier: String?,
        previousModifiers: Set<YabaiModifier>
    ) -> OverlayAction {
        if !samplesYabaiModifiers {
            activeModifiers = []
        }
        let presentationChanged = previousQualifier != yabaiQualifier
            || previousModifiers != activeModifiers
        if action == .none,
           presentationChanged,
           isVisible,
           visibleLayer == LayerName.yabai
        {
            return .refresh
        }
        return action
    }
}

// MARK: - UI controller

@available(macOS 14, *)
final class OverlayController {
    private let config: Config
    private let registry: KeybindingRegistry?
    private let logic: OverlayLogic
    private let defaults: UserDefaults
    private let modifierFlags: () -> UInt
    private let pomodoroStatusReader: () -> PomodoroStatus?
    private let presentsPanels: Bool
    private var panel: OverlayPanel?
    private var hostView: NSHostingView<KeyboardView>?
    private var delayTimer: Timer?
    private var modifierTimer: Timer?
    private var pomodoroTimer: Timer?
    private var pomodoroStatus: PomodoroStatus?
    private var currentLayer: String?

    var isModifierTimerRunning: Bool { modifierTimer != nil }

    /// `presentsPanels: false` builds every panel exactly as usual but never
    /// puts one on screen, so tests can inspect the real presentation without
    /// flashing an overlay over whatever the user is doing.
    init(
        config: Config,
        registryResult: Result<KeybindingRegistry, Error>,
        defaults: UserDefaults = .standard,
        modifierFlags: @escaping () -> UInt = { NSEvent.modifierFlags.rawValue },
        pomodoroStatusReader: @escaping () -> PomodoroStatus? = { PomodoroStatus.read() },
        presentsPanels: Bool = true
    ) {
        self.config = config
        self.registry = try? registryResult.get()
        self.defaults = defaults
        self.modifierFlags = modifierFlags
        self.pomodoroStatusReader = pomodoroStatusReader
        self.presentsPanels = presentsPanels
        let storedProfileId = defaults.string(
            forKey: KeyboardGeometrySelection.defaultsKey
        )
        self.logic = OverlayLogic(
            config: config,
            registry: self.registry,
            storedGeometryProfileId: storedProfileId
        )
        persistNormalizedProfileSelection(storedProfileId: storedProfileId)
    }

    /// The selection normalizes a stored profile id the registry no longer
    /// declares; writing the normalized id back keeps the next launch on the
    /// profile this one actually shows.
    private func persistNormalizedProfileSelection(storedProfileId: String?) {
        guard registry?.views.keyboardLayers?.geometry?.profiles != nil,
              let normalizedProfileId = logic.selectedGeometryProfileId,
              normalizedProfileId != storedProfileId
        else { return }
        defaults.set(
            normalizedProfileId,
            forKey: KeyboardGeometrySelection.defaultsKey
        )
    }

    deinit {
        delayTimer?.invalidate()
        modifierTimer?.invalidate()
        pomodoroTimer?.invalidate()
    }

    func handleLayerChange(_ layer: String) {
        let wasSampling = logic.samplesYabaiModifiers
        let action = logic.handleLayerChange(layer)
        let startedSampling = !wasSampling && logic.samplesYabaiModifiers
        let stoppedSampling = wasSampling && !logic.samplesYabaiModifiers

        if startedSampling, action == .refresh {
            // Seed the glyphs from the live flags so the refresh paints the
            // modifiers that are already held down.
            _ = logic.handleModifierFlags(modifierFlags())
            executeAction(action, refit: false)
            return
        }

        executeAction(action)

        if stoppedSampling,
           logic.isVisible,
           logic.visibleLayer == LayerName.yabai,
           case .startDelay = action
        {
            // The Yabai overlay stays on screen behind the new layer's delay;
            // repaint it so its now-stale modifier glyphs disappear.
            refreshOverlay(refit: false)
        }
    }

    func handleConnectionChange(_ connected: Bool) {
        let action = logic.handleConnectionChange(connected)
        executeAction(action, refit: false)
    }

    func handleMessage(_ message: String) {
        let preservesPendingDelay = message.hasPrefix(OverlayMessage.geometrySelectPrefix)
        if !preservesPendingDelay {
            delayTimer?.invalidate()
            delayTimer = nil
        }

        let action = logic.handleMessage(message)
        executeAction(action)
    }

    private func executeAction(
        _ action: OverlayAction,
        refit: Bool = true
    ) {
        defer {
            synchronizeModifierTimer()
            synchronizePomodoroTimer()
        }
        switch action {
        case .startDelay:
            startDelayTimer()
        case .retargetDelay:
            break
        case .show(let layerName):
            sampleBeforePresentingLiveYabai()
            showOverlay(for: layerName)
        case .replace(let layerName):
            sampleBeforePresentingLiveYabai()
            replaceOverlay(with: layerName)
        case .hide:
            delayTimer?.invalidate()
            delayTimer = nil
            hideOverlay()
        case .refresh:
            refreshOverlay(refit: refit)
        case .geometryChanged(let id, let refreshVisibleOverlay, let persistSelection):
            if persistSelection {
                defaults.set(id, forKey: KeyboardGeometrySelection.defaultsKey)
            }
            if refreshVisibleOverlay {
                refreshOverlay()
            }
        case .none:
            break
        }
    }

    private func startDelayTimer() {
        delayTimer?.invalidate()
        let delay = Double(config.display.delay_ms) / 1000.0
        delayTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.onDelayExpired()
        }
    }

    private func onDelayExpired() {
        delayTimer = nil
        let action = logic.delayExpired()
        executeAction(action)
    }

    func sampleModifierFlags() {
        let action = logic.handleModifierFlags(modifierFlags())
        executeAction(action, refit: false)
    }

    private func sampleBeforePresentingLiveYabai() {
        guard logic.samplesYabaiModifiers else { return }
        _ = logic.handleModifierFlags(modifierFlags())
    }

    private func synchronizeModifierTimer() {
        guard logic.samplesYabaiModifiers, panel != nil else {
            modifierTimer?.invalidate()
            modifierTimer = nil
            return
        }
        guard modifierTimer == nil else { return }
        modifierTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: true
        ) { [weak self] _ in
            self?.sampleModifierFlags()
        }
    }

    private func synchronizePomodoroTimer() {
        guard currentLayer == LayerName.pomodoro, panel != nil else {
            pomodoroTimer?.invalidate()
            pomodoroTimer = nil
            return
        }
        guard pomodoroTimer == nil else { return }
        pomodoroTimer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            self?.samplePomodoroStatus()
        }
    }

    private func samplePomodoroStatus() {
        guard currentLayer == LayerName.pomodoro, panel != nil else { return }
        let status = pomodoroStatusReader()
        guard status != pomodoroStatus else { return }
        pomodoroStatus = status
        refreshOverlay(refit: false)
    }

    private func hasPresentation(for layerName: String) -> Bool {
        KeyboardLayerProjector.presentation(
            layerName: layerName,
            legacyLayer: config.layers[layerName],
            registry: registry,
            showFree: logic.showFreeModifierSpace,
            geometryProfileId: logic.selectedGeometryProfileId
        ) != nil
    }

    private func showOverlay(for layerName: String) {
        guard hasPresentation(for: layerName) else { return }

        hideOverlay()
        currentLayer = layerName
        pomodoroStatus = layerName == LayerName.pomodoro ? pomodoroStatusReader() : nil

        let screen = targetScreen()

        let view = makeKeyboardView(layerName: layerName)
        let hostView = NSHostingView(rootView: view)
        let panelRect = fit(hostView, on: screen)

        let panel = OverlayPanel(contentRect: panelRect)
        panel.contentView = hostView
        panel.alphaValue = 0

        fadeIn(panel)

        self.panel = panel
        self.hostView = hostView
        Log.info("Showing overlay for layer: \(layerName)")
    }

    private func makeKeyboardView(layerName: String) -> KeyboardView {
        KeyboardView(
            layerName: layerName,
            legacyLayer: config.layers[layerName],
            display: config.display,
            registry: registry,
            showFreeModifierSpace: logic.showFreeModifierSpace,
            geometryProfileId: logic.selectedGeometryProfileId,
            showInputPath: logic.showsInputPath(for: layerName),
            activeModifiers: logic.activeModifiers,
            yabaiQualifier: logic.yabaiQualifier,
            pomodoroStatus: pomodoroStatus
        )
    }

    private func refreshOverlay(refit: Bool = true) {
        guard
            let currentLayer,
            let hostView,
            let panel
        else { return }
        hostView.rootView = makeKeyboardView(layerName: currentLayer)

        if refit {
            panel.setFrame(
                fit(hostView, on: targetScreen(preferring: panel.screen)),
                display: true
            )
        }
    }

    private func replaceOverlay(with layerName: String) {
        guard
            let hostView,
            let panel
        else { return }
        currentLayer = layerName
        pomodoroStatus = layerName == LayerName.pomodoro ? pomodoroStatusReader() : nil
        hostView.rootView = makeKeyboardView(layerName: layerName)

        panel.setFrame(
            fit(hostView, on: targetScreen(preferring: panel.screen)),
            display: true
        )
        Log.info("Replacing overlay content for layer: \(layerName)")
    }

    /// The screen the overlay belongs on: the panel's own screen while it has
    /// one, otherwise the active screen, falling back to the first attached
    /// screen so there is always a frame to fit into.
    private func targetScreen(preferring screen: NSScreen? = nil) -> NSScreen {
        screen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func fit(
        _ hostView: NSHostingView<KeyboardView>,
        on screen: NSScreen
    ) -> NSRect {
        let screenFrame = screen.frame
        let targetWidth = screenFrame.width * CGFloat(config.display.width_percent) / 100
        hostView.frame = NSRect(x: 0, y: 0, width: targetWidth, height: 1)
        hostView.invalidateIntrinsicContentSize()
        hostView.layoutSubtreeIfNeeded()
        let fittingSize = hostView.fittingSize
        hostView.frame = NSRect(origin: .zero, size: fittingSize)
        return NSRect(
            x: screenFrame.midX - fittingSize.width / 2,
            y: screenFrame.midY - fittingSize.height / 2,
            width: fittingSize.width,
            height: fittingSize.height
        )
    }

    private func hideOverlay() {
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
        pomodoroStatus = nil
        guard let panel = self.panel else { return }
        currentLayer = nil

        fadeOut(panel)

        self.panel = nil
        self.hostView = nil
        Log.debug("Hiding overlay")
    }

    /// Reveals `panel` at the configured opacity. A headless controller keeps
    /// it off screen and lands on the final opacity straight away instead of
    /// animating towards it.
    private func fadeIn(_ panel: OverlayPanel) {
        let opacity = CGFloat(config.display.opacity)
        guard presentsPanels else {
            panel.alphaValue = opacity
            return
        }
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Double(config.display.fade_in_ms) / 1000.0
            panel.animator().alphaValue = opacity
        }
    }

    /// Retires `panel`. A headless controller applies the faded-out state and
    /// runs the animation's completion work synchronously, so the panel is
    /// already retired when this returns.
    private func fadeOut(_ panel: OverlayPanel) {
        guard presentsPanels else {
            panel.alphaValue = 0
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Double(config.display.fade_out_ms) / 1000.0
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}
