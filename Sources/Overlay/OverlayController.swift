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

    init(config: Config) {
        self.config = config
    }

    func handleLayerChange(_ layer: String) -> OverlayAction {
        if config.layers[layer] != nil {
            pendingLayer = layer
            return .startDelay(layer)
        } else {
            pendingLayer = nil
            return .hide
        }
    }

    func delayExpired(for layer: String) -> OverlayAction {
        guard pendingLayer == layer else { return .none }
        return .show(layer)
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
        switch action {
        case .startDelay(let layerName):
            let delay = Double(config.display.delay_ms) / 1000.0
            delayTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.onDelayExpired(for: layerName)
            }
        case .hide:
            hideOverlay()
        case .show, .none:
            break
        }
    }

    private func onDelayExpired(for layer: String) {
        let action = logic.delayExpired(for: layer)
        switch action {
        case .show(let layerName):
            showOverlay(for: layerName)
        case .hide:
            hideOverlay()
        case .startDelay, .none:
            break
        }
    }

    private func showOverlay(for layerName: String) {
        guard let layerConfig = config.layers[layerName] else { return }

        hideOverlay()
        currentLayer = layerName

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame

        let view = KeyboardView(layerName: layerName, layer: layerConfig, display: config.display)
        let hostView = NSHostingView(rootView: view)
        hostView.frame = NSRect(x: 0, y: 0, width: screenFrame.width * 0.8, height: screenFrame.height * 0.6)
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
