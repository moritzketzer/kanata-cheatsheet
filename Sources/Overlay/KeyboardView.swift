// Sources/Overlay/KeyboardView.swift
import SwiftUI

// MARK: - Keyboard geometry (ANSI layout)

struct KeyDef {
    let label: String
    let width: CGFloat

    init(_ label: String, _ width: CGFloat = 1.0) {
        self.label = label
        self.width = width
    }
}

enum KeyboardLayout {
    static let rows: [[KeyDef]] = [
        [KeyDef("`"), KeyDef("1"), KeyDef("2"), KeyDef("3"), KeyDef("4"), KeyDef("5"),
         KeyDef("6"), KeyDef("7"), KeyDef("8"), KeyDef("9"), KeyDef("0"), KeyDef("-"), KeyDef("="), KeyDef("Backspace", 1.5)],
        [KeyDef("Tab", 1.5), KeyDef("Q"), KeyDef("W"), KeyDef("E"), KeyDef("R"), KeyDef("T"),
         KeyDef("Y"), KeyDef("U"), KeyDef("I"), KeyDef("O"), KeyDef("P"), KeyDef("["), KeyDef("]"), KeyDef("\\")],
        [KeyDef("Caps", 1.75), KeyDef("A"), KeyDef("S"), KeyDef("D"), KeyDef("F"), KeyDef("G"),
         KeyDef("H"), KeyDef("J"), KeyDef("K"), KeyDef("L"), KeyDef(";"), KeyDef("'"), KeyDef("Return", 1.75)],
        [KeyDef("Shift", 2.25), KeyDef("Z"), KeyDef("X"), KeyDef("C"), KeyDef("V"), KeyDef("B"),
         KeyDef("N"), KeyDef("M"), KeyDef(","), KeyDef("."), KeyDef("/"), KeyDef("Shift", 2.25)],
        [KeyDef("Ctrl", 1.25), KeyDef("Opt", 1.25), KeyDef("Cmd", 1.25), KeyDef("Space", 5.0),
         KeyDef("Cmd", 1.25), KeyDef("Opt", 1.25), KeyDef("Fn", 1.25)],
    ]
}

// MARK: - Color parsing

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            r = 1; g = 0; b = 1; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Resolved key data

struct ResolvedKey {
    let label: String
    let description: String?
    let color: Color?
    let isActive: Bool
}

enum KeyResolver {
    static func resolve(layout: [[KeyDef]], layer: Config.Layer) -> [[ResolvedKey]] {
        var lookup: [String: (String, Color)] = [:]
        for (_, group) in layer.groups {
            let color = Color(hex: group.color)
            for (key, desc) in group.keys {
                lookup[key] = (desc, color)
            }
        }

        return layout.map { row in
            row.map { keyDef in
                if let (desc, color) = lookup[keyDef.label] {
                    return ResolvedKey(label: keyDef.label, description: desc, color: color, isActive: true)
                } else {
                    return ResolvedKey(label: keyDef.label, description: nil, color: nil, isActive: false)
                }
            }
        }
    }
}

// MARK: - SwiftUI Views

@available(macOS 14, *)
struct KeyboardView: View {
    let layerLabel: String
    let resolvedKeys: [[ResolvedKey]]
    let keyWidths: [[CGFloat]]
    let groups: [(String, Color)]
    let config: Config.Display

    let keySize: CGFloat
    static let keySpacing: CGFloat = 4

    init(layerName: String, layer: Config.Layer, display: Config.Display) {
        // Derive key size from width_percent and screen width.
        // The widest row (bottom/space row) has ~12.5 key-units total.
        // Solve: totalRowWidth + padding = screenWidth * percent/100
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        let targetWidth = screenWidth * CGFloat(display.width_percent) / 100.0
        let maxRowUnits: CGFloat = KeyboardLayout.rows.map { row in
            row.map { $0.width }.reduce(0, +)
        }.max() ?? 14.0
        let padding: CGFloat = 64 + CGFloat(maxRowUnits - 1) * KeyboardView.keySpacing
        self.keySize = (targetWidth - padding) / maxRowUnits
        self.layerLabel = layer.label
        self.resolvedKeys = KeyResolver.resolve(layout: KeyboardLayout.rows, layer: layer)
        self.keyWidths = KeyboardLayout.rows.map { row in
            row.map { $0.width }
        }
        self.groups = layer.groups.map { (name, group) in
            (name, Color(hex: group.color))
        }.sorted { $0.0 < $1.0 }
        self.config = display
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(layerLabel)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#cba6f7"))
                .tracking(4)
                .textCase(.uppercase)

            VStack(spacing: KeyboardView.keySpacing) {
                ForEach(0..<resolvedKeys.count, id: \.self) { rowIndex in
                    HStack(spacing: KeyboardView.keySpacing) {
                        ForEach(0..<resolvedKeys[rowIndex].count, id: \.self) { colIndex in
                            let key = resolvedKeys[rowIndex][colIndex]
                            let width = keyWidths[rowIndex][colIndex]
                            KeyCell(key: key, width: width * keySize, height: keySize)
                        }
                    }
                }
            }

            if !groups.isEmpty {
                HStack(spacing: 24) {
                    ForEach(groups, id: \.0) { name, color in
                        HStack(spacing: 6) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#6c7086"))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: CGFloat(config.corner_radius))
                .fill(Color(hex: config.background_color))
        )
    }
}

@available(macOS 14, *)
struct KeyCell: View {
    let key: ResolvedKey
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let labelSize = height * (key.isActive ? 0.27 : 0.23)
        let descSize = height * 0.18
        VStack(spacing: 1) {
            Text(key.label)
                .font(.system(size: labelSize, weight: key.isActive ? .bold : .regular, design: .monospaced))
                .foregroundColor(key.isActive ? (key.color ?? .white) : Color(hex: "#45475a"))
            if let desc = key.description {
                Text(desc)
                    .font(.system(size: descSize, design: .monospaced))
                    .foregroundColor(Color(hex: "#bac2de"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(key.isActive
                    ? (key.color ?? .white).opacity(0.12)
                    : Color(hex: "#313244").opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(key.isActive
                    ? (key.color ?? .white).opacity(0.2)
                    : Color(hex: "#cdd6f4").opacity(0.04), lineWidth: 1)
        )
    }
}
