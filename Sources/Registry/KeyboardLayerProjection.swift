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
    let primary: RegistryKeyVisual?
    let holdModifier: String?
    let explanation: String?
    var keyLabel: String? = nil
    var slotID: String? = nil

    var viewID: String { slotID ?? id }

    static func == (lhs: KeyboardPresentedKey, rhs: KeyboardPresentedKey) -> Bool {
        lhs.id == rhs.id
            && lhs.badge == rhs.badge
            && lhs.actionLabel == rhs.actionLabel
            && lhs.freeLabel == rhs.freeLabel
            && lhs.colorHex == rhs.colorHex
            && lhs.primary == rhs.primary
            && lhs.holdModifier == rhs.holdModifier
            && lhs.explanation == rhs.explanation
            && lhs.keyLabel == rhs.keyLabel
    }
}


struct KeyboardPresentedGroup: Equatable, Identifiable {
    let id: String
    let colorHex: String
}


struct KeyboardPresentedDefySlot: Equatable {
    let firmwareKey: String
    let sourceKey: String?
    let mineHoldModifier: String?
    let key: KeyboardPresentedKey?
}


struct KeyboardPresentedDefyThumbs: Equatable {
    let label: String
    let leftTop: [KeyboardPresentedKey]
    let leftBottom: [KeyboardPresentedKey]
    let rightTop: [KeyboardPresentedKey]
    let rightBottom: [KeyboardPresentedKey]

    var allKeys: [KeyboardPresentedKey] {
        leftTop + leftBottom + rightTop + rightBottom
    }
}


struct KeyboardPresentedDefyThumbRows: Equatable {
    let top: [KeyboardPresentedDefySlot?]
    let bottom: [KeyboardPresentedDefySlot?]

    var allKeys: [KeyboardPresentedKey] {
        (top + bottom).compactMap { $0?.key }
    }
}


struct KeyboardPresentedDefyHalf: Equatable {
    let rows: [[KeyboardPresentedDefySlot?]]
    let thumbs: KeyboardPresentedDefyThumbRows

    var allKeys: [KeyboardPresentedKey] {
        rows.flatMap { $0 }.compactMap { $0?.key } + thumbs.allKeys
    }
}


struct KeyboardPresentedArrowCluster: Equatable {
    let up: KeyboardPresentedKey
    let left: KeyboardPresentedKey
    let down: KeyboardPresentedKey
    let right: KeyboardPresentedKey

    var allKeys: [KeyboardPresentedKey] {
        [up, left, down, right]
    }
}


enum KeyboardPresentedGeometry: Equatable {
    case macbook(
        rows: [[KeyboardPresentedKey]],
        arrows: KeyboardPresentedArrowCluster
    )
    case defy(
        left: KeyboardPresentedDefyHalf,
        right: KeyboardPresentedDefyHalf
    )
    case legacy(
        rows: [[KeyboardPresentedKey]],
        arrows: KeyboardPresentedArrowCluster?,
        thumbs: KeyboardPresentedDefyThumbs?
    )

    var allKeys: [KeyboardPresentedKey] {
        switch self {
        case .macbook(let rows, let arrows):
            return rows.flatMap { $0 } + arrows.allKeys
        case .defy(let left, let right):
            return left.allKeys + right.allKeys
        case .legacy(let rows, let arrows, let thumbs):
            return rows.flatMap { $0 }
                + (arrows?.allKeys ?? [])
                + (thumbs?.allKeys ?? [])
        }
    }
}


struct KeyboardLayerPresentation: Equatable {
    let name: String
    let label: String
    let trigger: String
    let source: KeyboardPresentationSource
    let geometry: KeyboardPresentedGeometry
    let groups: [KeyboardPresentedGroup]
    var footer: RegistryLayerFooter? = nil

    init(
        name: String,
        label: String,
        trigger: String,
        source: KeyboardPresentationSource,
        geometry: KeyboardPresentedGeometry,
        groups: [KeyboardPresentedGroup],
        footer: RegistryLayerFooter? = nil
    ) {
        self.name = name
        self.label = label
        self.trigger = trigger
        self.source = source
        self.geometry = geometry
        self.groups = groups
        self.footer = footer
    }

    init(
        name: String,
        label: String,
        trigger: String,
        source: KeyboardPresentationSource,
        rows: [[KeyboardPresentedKey]],
        groups: [KeyboardPresentedGroup],
        defyThumbs: KeyboardPresentedDefyThumbs? = nil,
        arrowCluster: KeyboardPresentedArrowCluster? = nil,
        footer: RegistryLayerFooter? = nil
    ) {
        self.init(
            name: name,
            label: label,
            trigger: trigger,
            source: source,
            geometry: .legacy(
                rows: rows,
                arrows: arrowCluster,
                thumbs: defyThumbs
            ),
            groups: groups,
            footer: footer
        )
    }

    var rows: [[KeyboardPresentedKey]] {
        switch geometry {
        case .macbook(let rows, _), .legacy(let rows, _, _):
            return rows
        case .defy:
            return []
        }
    }

    var defyThumbs: KeyboardPresentedDefyThumbs? {
        guard case .legacy(_, _, let thumbs) = geometry else { return nil }
        return thumbs
    }

    var arrowCluster: KeyboardPresentedArrowCluster? {
        switch geometry {
        case .macbook(_, let arrows):
            return arrows
        case .legacy(_, let arrows, _):
            return arrows
        case .defy:
            return nil
        }
    }

    var hasHoldModifiers: Bool {
        geometry.allKeys.contains { $0.holdModifier != nil }
    }

    func key(at position: String) -> KeyboardPresentedKey? {
        geometry.allKeys.first { $0.id == position }
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
        showFree: Bool,
        geometryProfileId: String? = nil
    ) -> KeyboardLayerPresentation? {
        if let keyboardLayers = registry?.views.keyboardLayers,
           let geometry = keyboardLayers.geometry,
           let layer = keyboardLayers.layers[layerName]
        {
            let showBaseKeys = layer.showBaseKeys ?? false
            let groupColors = Dictionary(
                uniqueKeysWithValues: layer.groups.map { ($0.id, $0.color) }
            )
            let projectPosition = {
                (
                    position: RegistryKeyboardPosition,
                    useNamedBadge: Bool,
                    slotID: String
                ) -> KeyboardPresentedKey in
                let cell = layer.cells[position.position]
                let isPassthrough = cell?.group == "passthrough"
                let freeMineKey = cell == nil && showFree && !showBaseKeys
                    ? position.mineKey
                    : nil
                let canonicalBadge: String?
                if useNamedBadge {
                    canonicalBadge = position.namedKey
                } else if showBaseKeys {
                    canonicalBadge = position.mineKey ?? position.namedKey
                } else {
                    canonicalBadge = cell?.displayKey ?? freeMineKey
                }
                let sourceBadge = canonicalBadge.map { position.badge ?? $0 }
                let primary: RegistryKeyVisual?
                let holdModifier: String?
                let explanation: String?
                if isPassthrough {
                    primary = nil
                    holdModifier = nil
                    explanation = nil
                } else if let presentation = cell?.presentation {
                    primary = presentation.primary
                    holdModifier = presentation.holdModifier
                    explanation = presentation.explanation
                } else {
                    primary = cell?.icon.map {
                        RegistryKeyVisual(kind: $0.kind, token: $0.token)
                    }
                    holdModifier = nil
                    explanation = cell?.actionLabel
                }
                return KeyboardPresentedKey(
                    id: position.position,
                    width: position.width,
                    badge: sourceBadge,
                    actionLabel: isPassthrough ? nil : cell?.actionLabel,
                    freeLabel: freeMineKey == nil ? nil : "Free",
                    colorHex: isPassthrough ? nil : cell.flatMap { groupColors[$0.group] },
                    primary: primary,
                    holdModifier: holdModifier,
                    explanation: explanation,
                    keyLabel: nil,
                    slotID: slotID
                )
            }

            let profiles = geometry.effectiveProfiles
            let selectedProfile = geometryProfileId.flatMap { requestedID in
                profiles.first { $0.id == requestedID }
            } ?? geometry.defaultProfileId.flatMap { defaultID in
                profiles.first { $0.id == defaultID }
            } ?? profiles.first
            guard let selectedProfile else { return nil }

            func projectRows(
                _ rows: [[RegistryKeyboardPosition?]],
                prefix: String,
                excluding positionIDs: Set<String> = []
            ) -> [[KeyboardPresentedKey]] {
                rows.enumerated().map { rowIndex, row in
                    row.enumerated().compactMap { slotIndex, position in
                        guard let position,
                              !positionIDs.contains(position.position)
                        else { return nil }
                        return projectPosition(
                            position,
                            false,
                            "\(prefix).row.\(rowIndex).slot.\(slotIndex)"
                        )
                    }
                }
            }

            func projectArrowCluster(
                _ cluster: RegistryArrowCluster,
                prefix: String
            ) -> KeyboardPresentedArrowCluster {
                KeyboardPresentedArrowCluster(
                    up: projectPosition(cluster.up, false, "\(prefix).up"),
                    left: projectPosition(cluster.left, false, "\(prefix).left"),
                    down: projectPosition(cluster.down, false, "\(prefix).down"),
                    right: projectPosition(cluster.right, false, "\(prefix).right")
                )
            }

            func projectDefySlots(
                _ slots: [RegistryDefySlot?],
                prefix: String
            ) -> [KeyboardPresentedDefySlot?] {
                slots.enumerated().map { slotIndex, slot in
                    guard let slot else { return nil }
                    let key = slot.position.map {
                        projectPosition(
                            $0,
                            false,
                            "\(prefix).slot.\(slotIndex)"
                        )
                    }
                    return KeyboardPresentedDefySlot(
                        firmwareKey: slot.firmwareKey,
                        sourceKey: slot.position?.sourceKey,
                        mineHoldModifier: slot.position?.mineHoldModifier,
                        key: key
                    )
                }
            }

            func projectDefyHalf(
                _ half: RegistryDefyHalf,
                prefix: String
            ) -> KeyboardPresentedDefyHalf {
                KeyboardPresentedDefyHalf(
                    rows: half.rows.enumerated().map { rowIndex, row in
                        projectDefySlots(row, prefix: "\(prefix).row.\(rowIndex)")
                    },
                    thumbs: KeyboardPresentedDefyThumbRows(
                        top: projectDefySlots(
                            half.thumbs.top,
                            prefix: "\(prefix).thumb.top"
                        ),
                        bottom: projectDefySlots(
                            half.thumbs.bottom,
                            prefix: "\(prefix).thumb.bottom"
                        )
                    )
                )
            }

            let presentedGeometry: KeyboardPresentedGeometry
            switch selectedProfile.kind {
            case "macbook":
                guard let profileRows = selectedProfile.rows,
                      let arrows = selectedProfile.arrowCluster
                else { return nil }
                let arrowPositionIDs = Set(arrows.allPositions.map(\.position))
                presentedGeometry = .macbook(
                    rows: projectRows(
                        profileRows,
                        prefix: selectedProfile.id,
                        excluding: arrowPositionIDs
                    ),
                    arrows: projectArrowCluster(
                        arrows,
                        prefix: "\(selectedProfile.id).arrows"
                    )
                )
            case "defy":
                guard let halves = selectedProfile.halves else { return nil }
                presentedGeometry = .defy(
                    left: projectDefyHalf(
                        halves.left,
                        prefix: "\(selectedProfile.id).left"
                    ),
                    right: projectDefyHalf(
                        halves.right,
                        prefix: "\(selectedProfile.id).right"
                    )
                )
            case "legacy":
                let profileRows = selectedProfile.rows
                    ?? geometry.rows.map { row in row.map(Optional.some) }
                let arrows = selectedProfile.arrowCluster ?? geometry.arrowCluster
                let arrowPositionIDs = Set(
                    arrows?.allPositions.map(\.position) ?? []
                )
                let legacyThumbs = geometry.defyThumbs.map { thumbs in
                    KeyboardPresentedDefyThumbs(
                        label: thumbs.label,
                        leftTop: thumbs.left.top.enumerated().map { index, position in
                            projectPosition(
                                position,
                                true,
                                "legacy.thumb.left.top.\(index)"
                            )
                        },
                        leftBottom: thumbs.left.bottom.enumerated().map { index, position in
                            projectPosition(
                                position,
                                true,
                                "legacy.thumb.left.bottom.\(index)"
                            )
                        },
                        rightTop: thumbs.right.top.enumerated().map { index, position in
                            projectPosition(
                                position,
                                true,
                                "legacy.thumb.right.top.\(index)"
                            )
                        },
                        rightBottom: thumbs.right.bottom.enumerated().map { index, position in
                            projectPosition(
                                position,
                                true,
                                "legacy.thumb.right.bottom.\(index)"
                            )
                        }
                    )
                }
                presentedGeometry = .legacy(
                    rows: projectRows(
                        profileRows,
                        prefix: "legacy",
                        excluding: arrowPositionIDs
                    ),
                    arrows: arrows.map {
                        projectArrowCluster($0, prefix: "legacy.arrows")
                    },
                    thumbs: legacyThumbs
                )
            default:
                return nil
            }
            return KeyboardLayerPresentation(
                name: layerName,
                label: layer.label,
                trigger: layer.trigger,
                source: .registry,
                geometry: presentedGeometry,
                groups: layer.groups.filter { $0.id != "passthrough" }.map {
                    KeyboardPresentedGroup(id: $0.id, colorHex: $0.color)
                },
                footer: layer.footer
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
                        primary: nil,
                        holdModifier: nil,
                        explanation: binding?.label
                    )
                }
            },
            groups: legacyLayer.groups.map {
                KeyboardPresentedGroup(id: $0.key, colorHex: $0.value.color)
            }.sorted { $0.id < $1.id }
        )
    }
}
