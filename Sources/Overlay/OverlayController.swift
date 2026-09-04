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

final class OverlayLogic {
    private let config: Config
    private let registryLayerTriggers: [String: String]
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

    var selectedGeometryProfileId: String? {
        geometrySelection.selectedProfileId
    }

    init(
        config: Config,
        registry: KeybindingRegistry? = nil,
        storedGeometryProfileId: String? = nil
    ) {
        self.config = config
        let keyboardLayers = registry?.views.keyboardLayers
        self.registryLayerTriggers = keyboardLayers?.layers.mapValues(\.trigger) ?? [:]
        self.registryOverlayGroups = keyboardLayers?.layers.compactMapValues(\.overlayGroup) ?? [:]
        self.defyGeometryProfileIds = Set(
            keyboardLayers?.geometry?.effectiveProfiles
                .filter { $0.kind == "defy" }
                .map(\.id)
                ?? []
        )
        self.hasMineLayerMetadata = keyboardLayers?.layers["mine"] != nil
        self.geometrySelection = KeyboardGeometrySelection(
            geometry: keyboardLayers?.geometry,
            storedProfileId: storedGeometryProfileId
        )
    }

    private func trigger(for layer: String) -> String? {
        registryLayerTriggers[layer] ?? config.layers[layer]?.trigger
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
        showInputPath && layer == "mine"
    }

    private func resetInputPathOutsideDefy() {
        guard let selectedGeometryProfileId,
              defyGeometryProfileIds.contains(selectedGeometryProfileId)
        else {
            showInputPath = false
            return
        }
    }

    func handleLayerChange(_ layer: String) -> OverlayAction {
        currentLayer = layer
        if layer != "apps" {
            showFreeModifierSpace = false
        }
        if isPinned, hasLayer(layer) {
            pendingLayer = nil
            guard visibleLayer != layer else { return .none }
            visibleLayer = layer
            if isVisible {
                return .replace(layer)
            }
            isVisible = true
            return .show(layer)
        }
        if isPinned {
            pendingLayer = nil
            return .none
        }
        if let trigger = trigger(for: layer) {
            if trigger == "manual" {
                pendingLayer = nil
                // Hide only if we're currently showing a *different* layer.
                // A LayerChange to the same layer we're showing is the kanata
                // multi (push-msg + layer-switch) landing — keep it visible.
                if isVisible && visibleLayer != layer {
                    isVisible = false
                    visibleLayer = nil
                    showFreeModifierSpace = false
                    showInputPath = false
                    return .hide
                }
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
        } else {
            pendingLayer = nil
            if isVisible {
                isVisible = false
                visibleLayer = nil
                showFreeModifierSpace = false
                showInputPath = false
                return .hide
            }
            return .hide
        }
    }

    func delayExpired() -> OverlayAction {
        guard let pendingLayer else { return .none }
        self.pendingLayer = nil
        isVisible = true
        visibleLayer = pendingLayer
        return .show(pendingLayer)
    }

    func handleMessage(_ message: String) -> OverlayAction {
        if message.hasPrefix("cheatsheet-geometry-select:") {
            let id = String(message.dropFirst("cheatsheet-geometry-select:".count))
            guard let selected = geometrySelection.select(id) else { return .none }
            resetInputPathOutsideDefy()
            return .geometryChanged(
                id: selected,
                refreshVisibleOverlay: isVisible,
                persistSelection: false
            )
        }
        if message.hasPrefix("cheatsheet-pin-toggle:") {
            if isPinned {
                isPinned = false
                pendingLayer = nil
                showFreeModifierSpace = false
                showInputPath = false
                isVisible = false
                visibleLayer = nil
                return .hide
            }
            let layer = String(message.dropFirst("cheatsheet-pin-toggle:".count))
            guard hasLayer(layer) else { return .none }
            pendingLayer = nil
            isPinned = true
            isVisible = true
            visibleLayer = layer
            showInputPath = false
            return .show(layer)
        }
        if message.hasPrefix("cheatsheet-show:") {
            let layer = String(message.dropFirst("cheatsheet-show:".count))
            guard hasLayer(layer) else { return .none }
            if layer != "apps" {
                showFreeModifierSpace = false
            }
            pendingLayer = nil
            isVisible = true
            visibleLayer = layer
            return .show(layer)
        }
        switch message {
        case "cheatsheet-geometry-toggle":
            guard let id = geometrySelection.toggle() else { return .none }
            resetInputPathOutsideDefy()
            return .geometryChanged(
                id: id,
                refreshVisibleOverlay: isVisible,
                persistSelection: true
            )
        case "cheatsheet-space-toggle-free":
            guard isVisible, visibleLayer == "apps" else { return .none }
            showFreeModifierSpace.toggle()
            return .refresh
        case "cheatsheet-input-path-toggle":
            guard isVisible,
                  isPinned,
                  hasMineLayerMetadata,
                  let selectedGeometryProfileId,
                  defyGeometryProfileIds.contains(selectedGeometryProfileId)
            else { return .none }
            showInputPath.toggle()
            return .refresh
        case "cheatsheet-show":
            guard let layer = currentLayer, hasLayer(layer) else { return .none }
            pendingLayer = nil
            isVisible = true
            visibleLayer = layer
            return .show(layer)
        case "cheatsheet-hide":
            pendingLayer = nil
            isPinned = false
            showFreeModifierSpace = false
            showInputPath = false
            if isVisible {
                isVisible = false
                visibleLayer = nil
                return .hide
            }
            return .none
        case "cheatsheet-toggle":
            if isVisible {
                isVisible = false
                visibleLayer = nil
                pendingLayer = nil
                showFreeModifierSpace = false
                showInputPath = false
                return .hide
            }
            guard let layer = currentLayer, hasLayer(layer) else { return .none }
            pendingLayer = nil
            isVisible = true
            visibleLayer = layer
            return .show(layer)
        default:
            return .none
        }
    }
}

// MARK: - UI controller

@available(macOS 14, *)
final class OverlayController {
    private let config: Config
    private let registry: KeybindingRegistry?
    private let logic: OverlayLogic
    private let defaults: UserDefaults
    private var panel: OverlayPanel?
    private var hostView: NSHostingView<KeyboardView>?
    private var delayTimer: Timer?
    private var currentLayer: String?

    init(
        config: Config,
        registryResult: Result<KeybindingRegistry, Error>,
        defaults: UserDefaults = .standard
    ) {
        self.config = config
        self.registry = try? registryResult.get()
        self.defaults = defaults
        let storedProfileId = defaults.string(
            forKey: KeyboardGeometrySelection.defaultsKey
        )
        self.logic = OverlayLogic(
            config: config,
            registry: self.registry,
            storedGeometryProfileId: storedProfileId
        )
        if self.registry?.views.keyboardLayers?.geometry?.profiles != nil,
           let normalizedProfileId = logic.selectedGeometryProfileId,
           normalizedProfileId != storedProfileId
        {
            defaults.set(
                normalizedProfileId,
                forKey: KeyboardGeometrySelection.defaultsKey
            )
        }
    }

    func handleLayerChange(_ layer: String) {
        let action = logic.handleLayerChange(layer)
        executeAction(action)
    }

    func handleMessage(_ message: String) {
        let preservesPendingDelay = message.hasPrefix("cheatsheet-geometry-select:")
        if !preservesPendingDelay {
            delayTimer?.invalidate()
            delayTimer = nil
        }

        let action = logic.handleMessage(message)
        executeAction(action)
    }

    private func executeAction(_ action: OverlayAction) {
        switch action {
        case .startDelay:
            delayTimer?.invalidate()
            let delay = Double(config.display.delay_ms) / 1000.0
            delayTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.onDelayExpired()
            }
        case .retargetDelay:
            break
        case .show(let layerName):
            showOverlay(for: layerName)
        case .replace(let layerName):
            replaceOverlay(with: layerName)
        case .hide:
            delayTimer?.invalidate()
            delayTimer = nil
            hideOverlay()
        case .refresh:
            refreshOverlay()
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

    private func onDelayExpired() {
        delayTimer = nil
        let action = logic.delayExpired()
        executeAction(action)
    }

    private func showOverlay(for layerName: String) {
        guard KeyboardLayerProjector.presentation(
            layerName: layerName,
            legacyLayer: config.layers[layerName],
            registry: registry,
            showFree: logic.showFreeModifierSpace,
            geometryProfileId: logic.selectedGeometryProfileId
        ) != nil else {
            return
        }

        hideOverlay()
        currentLayer = layerName

        let screen = NSScreen.main ?? NSScreen.screens[0]

        let view = makeKeyboardView(layerName: layerName)
        let hostView = NSHostingView(rootView: view)
        let panelRect = fit(hostView, on: screen)

        let panel = OverlayPanel(contentRect: panelRect)
        panel.contentView = hostView
        panel.alphaValue = 0

        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Double(config.display.fade_in_ms) / 1000.0
            panel.animator().alphaValue = CGFloat(config.display.opacity)
        }

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
            showInputPath: logic.showsInputPath(for: layerName)
        )
    }

    private func refreshOverlay() {
        guard
            let currentLayer,
            let hostView,
            let panel
        else { return }
        hostView.rootView = makeKeyboardView(layerName: currentLayer)

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        panel.setFrame(fit(hostView, on: screen), display: true)
    }

    private func replaceOverlay(with layerName: String) {
        guard
            let hostView,
            let panel
        else { return }
        currentLayer = layerName
        hostView.rootView = makeKeyboardView(layerName: layerName)

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        panel.setFrame(fit(hostView, on: screen), display: true)
        Log.info("Replacing overlay content for layer: \(layerName)")
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
        guard let panel = self.panel else { return }
        currentLayer = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Double(config.display.fade_out_ms) / 1000.0
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })

        self.panel = nil
        self.hostView = nil
        Log.debug("Hiding overlay")
    }
}
