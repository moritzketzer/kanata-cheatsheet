import Testing
import Foundation

@Suite("Config")
struct ConfigTests {
    @Test("parses complete config")
    func parseComplete() throws {
        let json = """
        {
          "connection": { "host": "localhost", "port": 7070, "reconnect_interval_ms": 3000 },
          "display": {
            "delay_ms": 2000, "fade_in_ms": 150, "fade_out_ms": 100,
            "opacity": 0.88, "position": "center", "width_percent": 75,
            "background_color": "#11111be0", "corner_radius": 16
          },
          "layers": {
            "nav": {
              "label": "NAV",
              "groups": {
                "Arrows": {
                  "color": "#89b4fa",
                  "keys": { "E": "Up", "S": "Left", "D": "Down", "F": "Right" }
                }
              }
            }
          }
        }
        """
        let config = try Config.parse(from: json.data(using: .utf8)!)
        #expect(config.connection.port == 7070)
        #expect(config.display.delay_ms == 2000)
        #expect(config.display.opacity == 0.88)
        #expect(config.layers["nav"]?.label == "NAV")
        #expect(config.layers["nav"]?.groups["Arrows"]?.color == "#89b4fa")
        #expect(config.layers["nav"]?.groups["Arrows"]?.keys["E"] == "Up")
    }

    @Test("uses defaults for missing fields")
    func defaults() throws {
        let json = """
        { "layers": {} }
        """
        let config = try Config.parse(from: json.data(using: .utf8)!)
        #expect(config.connection.host == "localhost")
        #expect(config.connection.port == 7070)
        #expect(config.connection.reconnect_interval_ms == 3000)
        #expect(config.display.delay_ms == 2000)
        #expect(config.display.fade_in_ms == 150)
        #expect(config.display.position == "center")
    }

    @Test("loads from file path")
    func loadFromFile() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-config-\(UUID().uuidString).json")
        let json = """
        { "connection": { "port": 9999 }, "layers": {} }
        """
        try json.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let config = try Config.load(from: tmp.path)
        #expect(config.connection.port == 9999)
    }

    @Test("empty JSON uses all defaults")
    func emptyJson() throws {
        let json = "{}"
        let config = try Config.parse(from: json.data(using: .utf8)!)
        #expect(config.connection.host == "localhost")
        #expect(config.layers.isEmpty)
    }
}
