import Foundation


enum YabaiModifier: String, CaseIterable, Codable, Hashable {
    case control
    case option
    case command
    case shift

    var outputMask: UInt {
        switch self {
        case .control: 0x1
        case .option: 0x20
        case .command: 0x8
        case .shift: 0x2
        }
    }

    var glyph: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .command: "⌘"
        case .shift: "⇧"
        }
    }

    var accentHex: String {
        switch self {
        case .control: "#f38ba8"
        case .option: "#b4befe"
        case .command: "#a6e3a1"
        case .shift: "#fab387"
        }
    }

    var roleLabel: String {
        switch self {
        case .control: "Resize"
        case .option: "Stack / Focus"
        case .command: "Warp / Follow"
        case .shift: "Swap / Move"
        }
    }

    static func active(in flags: UInt) -> Set<Self> {
        Set(allCases.filter { flags & $0.outputMask != 0 })
    }
}
