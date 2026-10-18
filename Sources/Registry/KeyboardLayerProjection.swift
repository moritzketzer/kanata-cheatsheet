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
    let actionModifier: YabaiModifier?
    let holdAccentHex: String?
    let isHoldActive: Bool
    var keyLabel: String? = nil
    var slotID: String? = nil

    init(
        id: String,
        width: Double,
        badge: String?,
        actionLabel: String?,
        freeLabel: String?,
        colorHex: String?,
        primary: RegistryKeyVisual?,
        holdModifier: String?,
        explanation: String?,
        actionModifier: YabaiModifier? = nil,
        holdAccentHex: String? = nil,
        isHoldActive: Bool = false,
        keyLabel: String? = nil,
        slotID: String? = nil
    ) {
        self.id = id
        self.width = width
        self.badge = badge
        self.actionLabel = actionLabel
        self.freeLabel = freeLabel
        self.colorHex = colorHex
        self.primary = primary
        self.holdModifier = holdModifier
        self.explanation = explanation
        self.actionModifier = actionModifier
        self.holdAccentHex = holdAccentHex
        self.isHoldActive = isHoldActive
        self.keyLabel = keyLabel
        self.slotID = slotID
    }

    var viewID: String { slotID ?? id }

    /// Compares rendered content only: `slotID` is view identity rather than
    /// content, and `width` is fixed geometry, so both stay out of the
    /// comparison.
    static func == (lhs: KeyboardPresentedKey, rhs: KeyboardPresentedKey) -> Bool {
        lhs.id == rhs.id
            && lhs.badge == rhs.badge
            && lhs.actionLabel == rhs.actionLabel
            && lhs.freeLabel == rhs.freeLabel
            && lhs.colorHex == rhs.colorHex
            && lhs.primary == rhs.primary
            && lhs.holdModifier == rhs.holdModifier
            && lhs.explanation == rhs.explanation
            && lhs.actionModifier == rhs.actionModifier
            && lhs.holdAccentHex == rhs.holdAccentHex
            && lhs.isHoldActive == rhs.isHoldActive
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
    var physicalId: String? = nil
    var mineKey: String? = nil
    var mineDisabled: Bool = false
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
    static let yabaiLayerName = "yabai"
    static let pomodoroLayerName = "pomodoro"

    let name: String
    let label: String
    let trigger: String
    let source: KeyboardPresentationSource
    let geometry: KeyboardPresentedGeometry
    let groups: [KeyboardPresentedGroup]
    var footer: RegistryLayerFooter? = nil

    var isYabaiLayer: Bool { name == Self.yabaiLayerName }
    var isPomodoroLayer: Bool { name == Self.pomodoroLayerName }

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


/// Geometry profile kinds this projector can render. The registry keeps the
/// kind as a free-form string for forward compatibility, so an unknown kind
/// fails `init(rawValue:)` and the projection yields no presentation, matching
/// the previous string switch's `default` case.
private enum GeometryProfileKind: String {
    case macbook
    case defy
    case legacy
}


/// Projects one registry keyboard layer onto a selected geometry profile.
/// Carries the per-layer inputs every slot projection needs so the individual
/// projection steps stay small.
private struct RegistryLayerProjectionBuilder {
    /// Cells in this group render as bare key caps and stay out of the legend.
    static let passthroughGroupID = "passthrough"

    /// What a cell contributes to a projected key once the active yabai
    /// modifier variant is resolved.
    private struct CellContent {
        static let empty = CellContent(
            primary: nil,
            holdModifier: nil,
            explanation: nil,
            actionModifier: nil
        )

        let primary: RegistryKeyVisual?
        let holdModifier: String?
        let explanation: String?
        let actionModifier: YabaiModifier?
    }

    let layerName: String
    let layer: RegistryKeyboardLayer
    let geometry: RegistryKeyboardGeometry
    let showFree: Bool
    let showBaseKeys: Bool
    let groupColors: [String: String]
    let activeModifiers: Set<YabaiModifier>

    init(
        layerName: String,
        layer: RegistryKeyboardLayer,
        geometry: RegistryKeyboardGeometry,
        showFree: Bool,
        activeModifiers: Set<YabaiModifier>
    ) {
        self.layerName = layerName
        self.layer = layer
        self.geometry = geometry
        self.showFree = showFree
        self.showBaseKeys = layer.showBaseKeys ?? false
        self.groupColors = Dictionary(
            uniqueKeysWithValues: layer.groups.map { ($0.id, $0.color) }
        )
        self.activeModifiers = activeModifiers
    }

    func presentation(
        profile: RegistryKeyboardGeometryProfile
    ) -> KeyboardLayerPresentation? {
        guard let presentedGeometry = presentedGeometry(for: profile) else { return nil }
        return KeyboardLayerPresentation(
            name: layerName,
            label: layer.label,
            trigger: layer.trigger,
            source: .registry,
            geometry: presentedGeometry,
            groups: layer.groups
                .filter { $0.id != Self.passthroughGroupID }
                .map { KeyboardPresentedGroup(id: $0.id, colorHex: $0.color) },
            footer: layer.footer
        )
    }

    private func presentedGeometry(
        for profile: RegistryKeyboardGeometryProfile
    ) -> KeyboardPresentedGeometry? {
        switch GeometryProfileKind(rawValue: profile.kind) {
        case .macbook:
            guard let profileRows = profile.rows,
                  let arrows = profile.arrowCluster
            else { return nil }
            return .macbook(
                rows: projectRows(
                    profileRows,
                    prefix: profile.id,
                    excluding: Set(arrows.allPositions.map(\.position))
                ),
                arrows: projectArrowCluster(arrows, prefix: "\(profile.id).arrows")
            )
        case .defy:
            guard let halves = profile.halves else { return nil }
            return .defy(
                left: projectDefyHalf(halves.left, prefix: "\(profile.id).left"),
                right: projectDefyHalf(halves.right, prefix: "\(profile.id).right")
            )
        case .legacy:
            return legacyGeometry(for: profile)
        case nil:
            return nil
        }
    }

    private func legacyGeometry(
        for profile: RegistryKeyboardGeometryProfile
    ) -> KeyboardPresentedGeometry {
        let profileRows = profile.rows
            ?? geometry.rows.map { row in row.map(Optional.some) }
        let arrows = profile.arrowCluster ?? geometry.arrowCluster
        let arrowPositionIDs = Set(arrows?.allPositions.map(\.position) ?? [])
        return .legacy(
            rows: projectRows(
                profileRows,
                prefix: "legacy",
                excluding: arrowPositionIDs
            ),
            arrows: arrows.map {
                projectArrowCluster($0, prefix: "legacy.arrows")
            },
            thumbs: geometry.defyThumbs.map(projectDefyThumbs)
        )
    }

    private func projectRows(
        _ rows: [[RegistryKeyboardPosition?]],
        prefix: String,
        excluding positionIDs: Set<String> = []
    ) -> [[KeyboardPresentedKey]] {
        rows.enumerated().map { rowIndex, row in
            row.enumerated().compactMap { slotIndex, position in
                guard let position,
                      !positionIDs.contains(position.position)
                else { return nil }
                return project(
                    position,
                    useNamedBadge: false,
                    slotID: "\(prefix).row.\(rowIndex).slot.\(slotIndex)"
                )
            }
        }
    }

    private func projectArrowCluster(
        _ cluster: RegistryArrowCluster,
        prefix: String
    ) -> KeyboardPresentedArrowCluster {
        KeyboardPresentedArrowCluster(
            up: project(cluster.up, useNamedBadge: false, slotID: "\(prefix).up"),
            left: project(cluster.left, useNamedBadge: false, slotID: "\(prefix).left"),
            down: project(cluster.down, useNamedBadge: false, slotID: "\(prefix).down"),
            right: project(cluster.right, useNamedBadge: false, slotID: "\(prefix).right")
        )
    }

    private func projectDefySlots(
        _ slots: [RegistryDefySlot?],
        prefix: String
    ) -> [KeyboardPresentedDefySlot?] {
        slots.enumerated().map { slotIndex, slot in
            guard let slot else { return nil }
            let key = slot.position.map {
                project(
                    $0,
                    useNamedBadge: false,
                    slotID: "\(prefix).slot.\(slotIndex)"
                )
            }
            return KeyboardPresentedDefySlot(
                firmwareKey: slot.firmwareKey,
                sourceKey: slot.position?.sourceKey,
                mineHoldModifier: slot.position?.mineHoldModifier,
                key: key,
                physicalId: slot.physicalId,
                mineKey: slot.position?.mineKey,
                mineDisabled: slot.position?.mineDisabled ?? false
            )
        }
    }

    private func projectDefyHalf(
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

    private func projectDefyThumbs(
        _ thumbs: RegistryDefyThumbs
    ) -> KeyboardPresentedDefyThumbs {
        KeyboardPresentedDefyThumbs(
            label: thumbs.label,
            leftTop: projectThumbRow(
                thumbs.left.top,
                prefix: "legacy.thumb.left.top"
            ),
            leftBottom: projectThumbRow(
                thumbs.left.bottom,
                prefix: "legacy.thumb.left.bottom"
            ),
            rightTop: projectThumbRow(
                thumbs.right.top,
                prefix: "legacy.thumb.right.top"
            ),
            rightBottom: projectThumbRow(
                thumbs.right.bottom,
                prefix: "legacy.thumb.right.bottom"
            )
        )
    }

    private func projectThumbRow(
        _ positions: [RegistryKeyboardPosition],
        prefix: String
    ) -> [KeyboardPresentedKey] {
        positions.enumerated().map { index, position in
            project(position, useNamedBadge: true, slotID: "\(prefix).\(index)")
        }
    }

    private func project(
        _ position: RegistryKeyboardPosition,
        useNamedBadge: Bool,
        slotID: String
    ) -> KeyboardPresentedKey {
        let cell = layer.cells[position.position]
        let isPassthrough = cell?.group == Self.passthroughGroupID
        let freeMineKey = cell == nil && showFree && !showBaseKeys
            ? position.mineKey
            : nil
        let badge = canonicalBadge(
            for: position,
            cell: cell,
            freeMineKey: freeMineKey,
            useNamedBadge: useNamedBadge
        )
        let content = isPassthrough ? CellContent.empty : cellContent(for: cell)
        let holdRole = isYabaiLayer
            ? content.holdModifier.flatMap(YabaiModifier.init(rawValue:))
            : nil
        return KeyboardPresentedKey(
            id: position.position,
            width: position.width,
            badge: badge.map { position.badge ?? $0 },
            actionLabel: isPassthrough ? nil : cell?.actionLabel,
            freeLabel: freeMineKey == nil ? nil : "Free",
            colorHex: isPassthrough
                ? nil
                : content.actionModifier?.accentHex
                    ?? cell.flatMap { groupColors[$0.group] },
            primary: content.primary,
            holdModifier: content.holdModifier,
            explanation: content.explanation,
            actionModifier: content.actionModifier,
            holdAccentHex: holdRole?.accentHex,
            isHoldActive: holdRole.map(activeModifiers.contains) ?? false,
            keyLabel: nil,
            slotID: slotID
        )
    }

    private func canonicalBadge(
        for position: RegistryKeyboardPosition,
        cell: RegistryKeyboardCell?,
        freeMineKey: String?,
        useNamedBadge: Bool
    ) -> String? {
        if useNamedBadge {
            return position.namedKey
        }
        if showBaseKeys {
            return position.mineKey ?? position.namedKey
        }
        return cell?.displayKey ?? freeMineKey
    }

    private func cellContent(for cell: RegistryKeyboardCell?) -> CellContent {
        guard let presentation = cell?.presentation else {
            return CellContent(
                primary: cell?.icon.map {
                    RegistryKeyVisual(kind: $0.kind, token: $0.token)
                },
                holdModifier: nil,
                explanation: cell?.actionLabel,
                actionModifier: nil
            )
        }
        let variant = isYabaiLayer
            ? presentation.modifierVariants?.first {
                activeModifiers.contains($0.modifier)
            }
            : nil
        return CellContent(
            primary: variant?.primary ?? presentation.primary,
            holdModifier: presentation.holdModifier,
            explanation: variant?.explanation ?? presentation.explanation,
            actionModifier: variant?.modifier
        )
    }

    private var isYabaiLayer: Bool {
        layerName == KeyboardLayerPresentation.yabaiLayerName
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
        geometryProfileId: String? = nil,
        activeModifiers: Set<YabaiModifier> = []
    ) -> KeyboardLayerPresentation? {
        if let keyboardLayers = registry?.views.keyboardLayers,
           let geometry = keyboardLayers.geometry,
           let layer = keyboardLayers.layers[layerName]
        {
            guard let profile = selectedProfile(
                in: geometry,
                requestedID: geometryProfileId
            ) else { return nil }
            return RegistryLayerProjectionBuilder(
                layerName: layerName,
                layer: layer,
                geometry: geometry,
                showFree: showFree,
                activeModifiers: activeModifiers
            ).presentation(profile: profile)
        }
        return legacyPresentation(layerName: layerName, legacyLayer: legacyLayer)
    }

    private static func selectedProfile(
        in geometry: RegistryKeyboardGeometry,
        requestedID: String?
    ) -> RegistryKeyboardGeometryProfile? {
        let profiles = geometry.effectiveProfiles
        return requestedID.flatMap { requestedID in
            profiles.first { $0.id == requestedID }
        } ?? geometry.defaultProfileId.flatMap { defaultID in
            profiles.first { $0.id == defaultID }
        } ?? profiles.first
    }

    private static func legacyPresentation(
        layerName: String,
        legacyLayer: Config.Layer?
    ) -> KeyboardLayerPresentation? {
        guard let legacyLayer else { return nil }
        var bindingsByKeyLabel: [String: (label: String, color: String)] = [:]
        for group in legacyLayer.groups.values {
            for (key, label) in group.keys {
                bindingsByKeyLabel[key] = (label, group.color)
            }
        }
        return KeyboardLayerPresentation(
            name: layerName,
            label: legacyLayer.label,
            trigger: legacyLayer.trigger,
            source: .legacy,
            rows: legacyRows.map { row in
                row.map { key in
                    let binding = bindingsByKeyLabel[key.label]
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
