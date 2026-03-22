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
        var position: String
        var width_percent: Int
        var background_color: String
        var corner_radius: Int

        init(
            delay_ms: Int = 2000, fade_in_ms: Int = 150, fade_out_ms: Int = 100,
            opacity: Double = 0.88, position: String = "center", width_percent: Int = 75,
            background_color: String = "#11111be0", corner_radius: Int = 16
        ) {
            self.delay_ms = delay_ms
            self.fade_in_ms = fade_in_ms
            self.fade_out_ms = fade_out_ms
            self.opacity = opacity
            self.position = position
            self.width_percent = width_percent
            self.background_color = background_color
            self.corner_radius = corner_radius
        }
    }

    struct Layer: Codable {
        var label: String
        var trigger: String  // "delay" (auto-show after delay) or "manual" (push-msg only)
        var groups: [String: Group]

        init(label: String, trigger: String = "delay", groups: [String: Group] = [:]) {
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
        self.connection = try container.decodeIfPresent(Connection.self, forKey: .connection) ?? Connection()
        self.display = try container.decodeIfPresent(Display.self, forKey: .display) ?? Display()
        self.layers = try container.decodeIfPresent([String: Layer].self, forKey: .layers) ?? [:]
    }
}

extension Config.Connection {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.host = try container.decodeIfPresent(String.self, forKey: .host) ?? "localhost"
        self.port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 7070
        self.reconnect_interval_ms = try container.decodeIfPresent(Int.self, forKey: .reconnect_interval_ms) ?? 3000
    }
}

extension Config.Layer {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try container.decode(String.self, forKey: .label)
        self.trigger = try container.decodeIfPresent(String.self, forKey: .trigger) ?? "delay"
        self.groups = try container.decodeIfPresent([String: Config.Group].self, forKey: .groups) ?? [:]
    }
}

extension Config.Display {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.delay_ms = try container.decodeIfPresent(Int.self, forKey: .delay_ms) ?? 2000
        self.fade_in_ms = try container.decodeIfPresent(Int.self, forKey: .fade_in_ms) ?? 150
        self.fade_out_ms = try container.decodeIfPresent(Int.self, forKey: .fade_out_ms) ?? 100
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.88
        self.position = try container.decodeIfPresent(String.self, forKey: .position) ?? "center"
        self.width_percent = try container.decodeIfPresent(Int.self, forKey: .width_percent) ?? 75
        self.background_color = try container.decodeIfPresent(String.self, forKey: .background_color) ?? "#11111be0"
        self.corner_radius = try container.decodeIfPresent(Int.self, forKey: .corner_radius) ?? 16
    }
}
