// Sources/App/main.swift
import AppKit

@available(macOS 14, *)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tcpClient: KanataTCPClient?
    private var overlayController: OverlayController?
    private var config: Config?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("kanata-cheatsheet starting")

        let configPath = Config.defaultConfigPath()
        do {
            config = try Config.load(from: configPath)
            Log.info("Loaded config from \(configPath)")
        } catch {
            Log.error("Failed to load config from \(configPath): \(error). Using defaults.")
            config = Config()
        }

        guard let config else { return }

        overlayController = OverlayController(config: config)

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
        case .other:
            break
        }
    }

    func didConnect() {
        Log.info("Connected to kanata TCP")
    }

    func didDisconnect() {
        Log.info("Disconnected from kanata TCP — will reconnect")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
