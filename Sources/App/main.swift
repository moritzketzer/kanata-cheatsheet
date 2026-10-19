// Sources/App/main.swift
import AppKit

@available(macOS 14, *)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tcpClient: KanataTCPClient?
    private var overlayController: OverlayController?
    private var browserController: RegistryBrowserController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("kanata-cheatsheet starting")

        let config = loadedConfig()
        let registryResult = loadedRegistry()
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

    /// The config file at the default path, falling back to the built-in
    /// defaults so a missing or broken file still leaves a usable app.
    private func loadedConfig() -> Config {
        let configPath = Config.defaultConfigPath()
        do {
            let config = try Config.load(from: configPath)
            Log.info("Loaded config from \(configPath)")
            return config
        } catch {
            Log.error("Failed to load config from \(configPath): \(error). Using defaults.")
            return Config()
        }
    }

    /// The registry load outcome. A failure is logged here and handed on, so
    /// the browser can show it rather than open empty.
    private func loadedRegistry() -> Result<KeybindingRegistry, Error> {
        let registryResult: Result<KeybindingRegistry, Error> = Result {
            try KeybindingRegistry.load()
        }
        if case .failure(let error) = registryResult {
            Log.error("Failed to load keybinding registry: \(error)")
        }
        return registryResult
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
