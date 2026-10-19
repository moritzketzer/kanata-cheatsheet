import Foundation

struct Config: Codable {
    var connection: Connection
    var display: Display
    var layers: [String: Layer]

    struct Connection: Codable {
        var host: String
        var port: Int
        var reconnect_interval_ms: Int

        init(host: String = "localhost", port: Int = 7070, reconnect_interval_ms: Int = 3000) {
            self.host = host
            self.port = port
            self.reconnect_interval_ms = reconnect_interval_ms
        }
    }

    struct Display: Codable {
        var delay_ms: Int
        var fade_in_ms: Int
        var fade_out_ms: Int
        var opacity: Double
        var width_percent: Int
        var background_color: String
        var corner_radius: Int

        init(
            delay_ms: Int = 2000, fade_in_ms: Int = 150, fade_out_ms: Int = 100,
            opacity: Double = 0.88, width_percent: Int = 75,
            background_color: String = "#11111be0", corner_radius: Int = 16
        ) {
            self.delay_ms = delay_ms
            self.fade_in_ms = fade_in_ms
            self.fade_out_ms = fade_out_ms
            self.opacity = opacity
            self.width_percent = width_percent
            self.background_color = background_color
            self.corner_radius = corner_radius
        }
    }

    struct Layer: Codable {
        /// Auto-show once the reveal delay expires.
        static let delayTrigger = "delay"
        /// Show only on an explicit `push-msg`.
        static let manualTrigger = "manual"

        var label: String
        /// Stays a plain `String` so an unrecognised value still decodes.
        var trigger: String
        var groups: [String: Group]

        init(label: String, trigger: String = Self.delayTrigger, groups: [String: Group] = [:]) {
            self.label = label
            self.trigger = trigger
            self.groups = groups
        }
    }

    struct Group: Codable {
        var color: String
        var keys: [String: String]
    }

    init(connection: Connection = Connection(), display: Display = Display(), layers: [String: Layer] = [:]) {
        self.connection = connection
        self.display = display
        self.layers = layers
    }

    static func parse(from data: Data) throws -> Config {
        let decoder = JSONDecoder()
        return try decoder.decode(Config.self, from: data)
    }

    static func load(from path: String) throws -> Config {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try parse(from: data)
    }

    static func defaultConfigPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/kanata-cheatsheet/config.json"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        self.connection = try container.decodeIfPresent(Connection.self, forKey: .connection) ?? defaults.connection
        self.display = try container.decodeIfPresent(Display.self, forKey: .display) ?? defaults.display
        self.layers = try container.decodeIfPresent([String: Layer].self, forKey: .layers) ?? defaults.layers
    }
}

// Every `init(from:)` below takes its fallbacks from a default-constructed
// instance, so the memberwise initializer stays the single source of defaults.

extension Config.Connection {
    /// A port outside this range cannot reach `NWEndpoint.Port`, so a bad
    /// config value falls back to the default instead of trapping at startup.
    static let validPortRange = 1...65535

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        self.host = try container.decodeIfPresent(String.self, forKey: .host) ?? defaults.host
        let decodedPort = try container.decodeIfPresent(Int.self, forKey: .port) ?? defaults.port
        self.port = Self.validPortRange.contains(decodedPort) ? decodedPort : defaults.port
        self.reconnect_interval_ms = try container.decodeIfPresent(Int.self, forKey: .reconnect_interval_ms)
            ?? defaults.reconnect_interval_ms
    }
}

extension Config.Layer {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let label = try container.decode(String.self, forKey: .label)
        let defaults = Self(label: label)
        self.label = label
        self.trigger = try container.decodeIfPresent(String.self, forKey: .trigger) ?? defaults.trigger
        self.groups = try container.decodeIfPresent([String: Config.Group].self, forKey: .groups)
            ?? defaults.groups
    }
}

extension Config.Display {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        self.delay_ms = try container.decodeIfPresent(Int.self, forKey: .delay_ms) ?? defaults.delay_ms
        self.fade_in_ms = try container.decodeIfPresent(Int.self, forKey: .fade_in_ms) ?? defaults.fade_in_ms
        self.fade_out_ms = try container.decodeIfPresent(Int.self, forKey: .fade_out_ms) ?? defaults.fade_out_ms
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? defaults.opacity
        self.width_percent = try container.decodeIfPresent(Int.self, forKey: .width_percent) ?? defaults.width_percent
        self.background_color = try container.decodeIfPresent(String.self, forKey: .background_color)
            ?? defaults.background_color
        self.corner_radius = try container.decodeIfPresent(Int.self, forKey: .corner_radius) ?? defaults.corner_radius
    }
}
