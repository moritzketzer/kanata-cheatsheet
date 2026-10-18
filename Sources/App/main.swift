// Sources/App/main.swift
import AppKit

@available(macOS 14, *)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tcpClient: KanataTCPClient?
    private var overlayController: OverlayController?
    private var browserController: RegistryBrowserController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("kanata-cheatsheet starting")

        let configPath = Config.defaultConfigPath()
        let config: Config
        do {
            config = try Config.load(from: configPath)
            Log.info("Loaded config from \(configPath)")
        } catch {
            Log.error("Failed to load config from \(configPath): \(error). Using defaults.")
            config = Config()
        }

        let registryResult: Result<KeybindingRegistry, Error> = Result {
            try KeybindingRegistry.load()
        }
        if case .failure(let error) = registryResult {
            Log.error("Failed to load keybinding registry: \(error)")
        }
        overlayController = OverlayController(config: config, registryResult: registryResult)
        browserController = RegistryBrowserController(registryResult: registryResult)

        let client = KanataTCPClient(
            host: config.connection.host,
            port: config.connection.port,
            reconnectInterval: Double(config.connection.reconnect_interval_ms) / 1000.0
        )
        client.delegate = self
        client.start()
        tcpClient = client

        Log.info("kanata-cheatsheet ready — connecting to \(config.connection.host):\(config.connection.port)")
    }
}

@available(macOS 14, *)
extension AppDelegate: KanataTCPClientDelegate {
    func didReceiveEvent(_ event: KanataEvent) {
        switch event {
        case .layerChange(let layer):
            Log.debug("Layer changed to: \(layer)")
            overlayController?.handleLayerChange(layer)
        case .messagePush(let message):
            Log.debug("Message received: \(message)")
            switch AppMessageRouter.route(message) {
            case .openRegistry:
                browserController?.open()
            case .overlay(let message):
                overlayController?.handleMessage(message)
            }
        case .other:
            break
        }
    }

    func didConnect() {
        Log.info("Connected to kanata TCP")
        overlayController?.handleConnectionChange(true)
    }

    func didDisconnect() {
        Log.info("Disconnected from kanata TCP — will reconnect")
        overlayController?.handleConnectionChange(false)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
