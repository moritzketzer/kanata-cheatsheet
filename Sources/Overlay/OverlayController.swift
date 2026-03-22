import AppKit
import SwiftUI

// MARK: - Pure logic (testable, no UI)

enum OverlayAction: Equatable {
    case startDelay(String)
    case show(String)
    case hide
    case none
}

final class OverlayLogic {
    private let config: Config
    private(set) var pendingLayer: String?
    private(set) var currentLayer: String?
    private(set) var isVisible = false

    init(config: Config) {
        self.config = config
    }

    func handleLayerChange(_ layer: String) -> OverlayAction {
        currentLayer = layer
        if let layerConfig = config.layers[layer] {
            if layerConfig.trigger == "manual" {
                // Manual layers never auto-show; hide if currently visible
                pendingLayer = nil
                if isVisible {
                    isVisible = false
                    return .hide
                }
                return .none
            }
            pendingLayer = layer
            return .startDelay(layer)
        } else {
            pendingLayer = nil
            if isVisible {
                isVisible = false
                return .hide
            }
            return .hide
        }
    }

    func delayExpired(for layer: String) -> OverlayAction {
        guard pendingLayer == layer else { return .none }
        isVisible = true
        return .show(layer)
    }

    func handleMessage(_ message: String) -> OverlayAction {
        switch message {
        case "cheatsheet-show":
            guard let layer = currentLayer, config.layers[layer] != nil else { return .none }
            pendingLayer = nil
            isVisible = true
            return .show(layer)
        case "cheatsheet-hide":
            pendingLayer = nil
            if isVisible {
                isVisible = false
                return .hide
            }
            return .none
        case "cheatsheet-toggle":
            if isVisible {
                isVisible = false
                pendingLayer = nil
                return .hide
            }
            guard let layer = currentLayer, config.layers[layer] != nil else { return .none }
            pendingLayer = nil
            isVisible = true
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
    private let logic: OverlayLogic
    private var panel: OverlayPanel?
    private var delayTimer: Timer?
    private var currentLayer: String?

    init(config: Config) {
        self.config = config
        self.logic = OverlayLogic(config: config)
    }

    func handleLayerChange(_ layer: String) {
        delayTimer?.invalidate()
        delayTimer = nil

        let action = logic.handleLayerChange(layer)
        executeAction(action)
    }

    func handleMessage(_ message: String) {
        delayTimer?.invalidate()
        delayTimer = nil

        let action = logic.handleMessage(message)
        executeAction(action)
    }

    private func executeAction(_ action: OverlayAction) {
        switch action {
        case .startDelay(let layerName):
            let delay = Double(config.display.delay_ms) / 1000.0
            delayTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.onDelayExpired(for: layerName)
            }
        case .show(let layerName):
            showOverlay(for: layerName)
        case .hide:
            hideOverlay()
        case .none:
            break
        }
    }

    private func onDelayExpired(for layer: String) {
        let action = logic.delayExpired(for: layer)
        executeAction(action)
    }

    private func showOverlay(for layerName: String) {
        guard let layerConfig = config.layers[layerName] else { return }

        hideOverlay()
        currentLayer = layerName

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame

        let view = KeyboardView(layerName: layerName, layer: layerConfig, display: config.display)
        let hostView = NSHostingView(rootView: view)
        let pct = CGFloat(config.display.width_percent) / 100.0
        hostView.frame = NSRect(x: 0, y: 0, width: screenFrame.width * pct, height: screenFrame.height * 0.8)
        let fittingSize = hostView.fittingSize

        let panelRect = NSRect(
            x: screenFrame.midX - fittingSize.width / 2,
            y: screenFrame.midY - fittingSize.height / 2,
            width: fittingSize.width,
            height: fittingSize.height
        )

        let panel = OverlayPanel(contentRect: panelRect)
        panel.contentView = hostView
        panel.alphaValue = 0

        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Double(config.display.fade_in_ms) / 1000.0
            panel.animator().alphaValue = CGFloat(config.display.opacity)
        }

        self.panel = panel
        Log.info("Showing overlay for layer: \(layerName)")
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
        Log.debug("Hiding overlay")
    }
}
