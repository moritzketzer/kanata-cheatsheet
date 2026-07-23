import Foundation


enum KeyboardPresentationSource: Equatable {
    case registry
    case legacy
}


struct KeyboardPresentedKey: Equatable, Identifiable {
    let id: String
    let width: Double
    let badge: String?
    let actionLabel: String?
    let freeLabel: String?
    let colorHex: String?
    let icon: RegistryKeyIcon?
}


struct KeyboardPresentedGroup: Equatable, Identifiable {
    let id: String
    let colorHex: String
}


struct KeyboardLayerPresentation: Equatable {
    let name: String
    let label: String
    let trigger: String
    let source: KeyboardPresentationSource
    let rows: [[KeyboardPresentedKey]]
    let groups: [KeyboardPresentedGroup]

    func key(at position: String) -> KeyboardPresentedKey? {
        rows.lazy.flatMap { $0 }.first { $0.id == position }
    }
}


enum KeyboardLayerProjector {
    private struct LegacyKey {
        let id: String
        let label: String
        let width: Double

        init(_ id: String, _ label: String, _ width: Double = 1.0) {
            self.id = id
            self.label = label
            self.width = width
        }
    }

    private static let legacyRows: [[LegacyKey]] = [
        [
            LegacyKey("Backquote", "`"), LegacyKey("Digit1", "1"), LegacyKey("Digit2", "2"),
            LegacyKey("Digit3", "3"), LegacyKey("Digit4", "4"), LegacyKey("Digit5", "5"),
            LegacyKey("Digit6", "6"), LegacyKey("Digit7", "7"), LegacyKey("Digit8", "8"),
            LegacyKey("Digit9", "9"), LegacyKey("Digit0", "0"), LegacyKey("Minus", "-"),
            LegacyKey("Equal", "="), LegacyKey("Backspace", "Backspace", 1.5),
        ],
        [
            LegacyKey("Tab", "Tab", 1.5), LegacyKey("KeyQ", "Q"), LegacyKey("KeyW", "W"),
            LegacyKey("KeyE", "E"), LegacyKey("KeyR", "R"), LegacyKey("KeyT", "T"),
            LegacyKey("KeyY", "Y"), LegacyKey("KeyU", "U"), LegacyKey("KeyI", "I"),
            LegacyKey("KeyO", "O"), LegacyKey("KeyP", "P"), LegacyKey("BracketLeft", "["),
            LegacyKey("BracketRight", "]"), LegacyKey("Backslash", "\\"),
        ],
        [
            LegacyKey("CapsLock", "Caps", 1.75), LegacyKey("KeyA", "A"),
            LegacyKey("KeyS", "S"), LegacyKey("KeyD", "D"), LegacyKey("KeyF", "F"),
            LegacyKey("KeyG", "G"), LegacyKey("KeyH", "H"), LegacyKey("KeyJ", "J"),
            LegacyKey("KeyK", "K"), LegacyKey("KeyL", "L"), LegacyKey("Semicolon", ";"),
            LegacyKey("Quote", "'"), LegacyKey("Enter", "Return", 1.75),
        ],
        [
            LegacyKey("ShiftLeft", "Shift", 2.25), LegacyKey("KeyZ", "Z"),
            LegacyKey("KeyX", "X"), LegacyKey("KeyC", "C"), LegacyKey("KeyV", "V"),
            LegacyKey("KeyB", "B"), LegacyKey("KeyN", "N"), LegacyKey("KeyM", "M"),
            LegacyKey("Comma", ","), LegacyKey("Period", "."), LegacyKey("Slash", "/"),
            LegacyKey("ShiftRight", "Shift", 2.25),
        ],
        [
            LegacyKey("ControlLeft", "Ctrl", 1.25), LegacyKey("AltLeft", "Opt", 1.25),
            LegacyKey("MetaLeft", "Cmd", 1.25), LegacyKey("Space", "Space", 5.0),
            LegacyKey("MetaRight", "Cmd", 1.25), LegacyKey("AltRight", "Opt", 1.25),
            LegacyKey("Fn", "Fn", 1.25),
        ],
    ]

    static func presentation(
        layerName: String,
        legacyLayer: Config.Layer?,
        registry: KeybindingRegistry?,
        showFree: Bool
    ) -> KeyboardLayerPresentation? {
        if let keyboardLayers = registry?.views.keyboardLayers,
           let geometry = keyboardLayers.geometry,
           let layer = keyboardLayers.layers[layerName]
        {
            let groupColors = Dictionary(
                uniqueKeysWithValues: layer.groups.map { ($0.id, $0.color) }
            )
            let rows = geometry.rows.map { row in
                row.map { position in
                    let cell = layer.cells[position.position]
                    let freeMineKey = cell == nil && showFree ? position.mineKey : nil
                    return KeyboardPresentedKey(
                        id: position.position,
                        width: position.width,
                        badge: cell?.displayKey ?? freeMineKey,
                        actionLabel: cell?.actionLabel,
                        freeLabel: freeMineKey == nil ? nil : "Free",
                        colorHex: cell.flatMap { groupColors[$0.group] },
                        icon: cell?.icon
                    )
                }
            }
            return KeyboardLayerPresentation(
                name: layerName,
                label: layer.label,
                trigger: layer.trigger,
                source: .registry,
                rows: rows,
                groups: layer.groups.map {
                    KeyboardPresentedGroup(id: $0.id, colorHex: $0.color)
                }
            )
        }

        guard let legacyLayer else { return nil }
        var keys: [String: (label: String, color: String)] = [:]
        for group in legacyLayer.groups.values {
            for (key, label) in group.keys {
                keys[key] = (label, group.color)
            }
        }
        return KeyboardLayerPresentation(
            name: layerName,
            label: legacyLayer.label,
            trigger: legacyLayer.trigger,
            source: .legacy,
            rows: legacyRows.map { row in
                row.map { key in
                    let binding = keys[key.label]
                    return KeyboardPresentedKey(
                        id: key.id,
                        width: key.width,
                        badge: key.label,
                        actionLabel: binding?.label,
                        freeLabel: nil,
                        colorHex: binding?.color,
                        icon: nil
                    )
                }
            },
            groups: legacyLayer.groups.map {
                KeyboardPresentedGroup(id: $0.key, colorHex: $0.value.color)
            }.sorted { $0.id < $1.id }
        )
    }
}
