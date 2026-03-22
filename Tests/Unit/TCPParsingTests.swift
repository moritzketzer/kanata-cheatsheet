import Testing
import Foundation

@Suite("TCP Parsing")
struct TCPParsingTests {
    @Test("parses LayerChange event")
    func layerChange() throws {
        let json = #"{"LayerChange":{"new":"nav"}}"#
        let event = try KanataEvent.parse(from: json)
        #expect(event == .layerChange("nav"))
    }

    @Test("parses LayerChange with different layer")
    func layerChangeYabai() throws {
        let json = #"{"LayerChange":{"new":"yabai"}}"#
        let event = try KanataEvent.parse(from: json)
        #expect(event == .layerChange("yabai"))
    }

    @Test("ignores non-LayerChange events")
    func otherEvents() throws {
        let json = #"{"MessagePush":{"message":"jump Safari"}}"#
        let event = try KanataEvent.parse(from: json)
        #expect(event == .other)
    }

    @Test("ignores malformed JSON")
    func malformed() throws {
        let event = try? KanataEvent.parse(from: "not json")
        #expect(event == nil)
    }

    @Test("parses multiple messages from buffer")
    func bufferSplit() throws {
        let buffer = #"{"LayerChange":{"new":"nav"}}"# + "\n" + #"{"LayerChange":{"new":"mine"}}"# + "\n"
        let events = KanataEvent.parseBuffer(buffer)
        #expect(events.count == 2)
        #expect(events[0] == .layerChange("nav"))
        #expect(events[1] == .layerChange("mine"))
    }
}
