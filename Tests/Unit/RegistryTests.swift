import Foundation
import Testing


private func registryCell(
    _ id: String,
    _ label: String,
    _ displayKey: String,
    _ sourceKey: String,
    _ group: String,
    _ iconToken: String,
    iconKind: String = "app-font",
    withPresentation: Bool = false
) -> [String: Any] {
    var cell: [String: Any] = [
        "bindingId": "test.\(id)",
        "displayKey": displayKey,
        "sourceKey": sourceKey,
        "actionLabel": label,
        "group": group,
        "icon": ["kind": iconKind, "token": iconToken],
    ]
    if withPresentation {
        cell["presentation"] = [
            "primary": ["kind": iconKind, "token": iconToken],
            "explanation": label,
        ]
    }
    return cell
}


private func namedKeyboardPosition(
    _ position: String,
    _ sourceKey: String,
    _ namedKey: String,
    badge: String? = nil
) -> [String: Any] {
    var result: [String: Any] = [
        "position": position,
        "sourceKey": sourceKey,
        "namedKey": namedKey,
        "width": 1.0,
    ]
    if let badge {
        result["badge"] = badge
    }
    return result
}


private func versionOneFixtureData(
    includeFooter: Bool = true,
    includeIconlessCell: Bool = false,
    includeGeometryProfiles: Bool = false
) throws -> Data {
    let slots: [[String: Any]] = (1...15).map { index in
        [
            "modifiers": index == 1 ? ["control"] : ["command"],
            "display": index == 1 ? "⌃ Space" : "⌘ Space",
            "state": index == 1 ? "free" : "occupied",
            "bindingIds": index == 1 ? [] : ["macos.spotlight"],
        ]
    }
    let optionalFinderIcon: Any = includeIconlessCell
        ? NSNull()
        : ["kind": "app-font", "token": ":finder:"]
    var yabaiLayer: [String: Any] = [
        "id": "yabai",
        "label": "Yabai",
        "trigger": "manual",
        "showBaseKeys": true,
        "groups": [
            ["id": "passthrough", "color": "#6c7086"],
            ["id": "windows", "color": "#cba6f7"],
        ],
        "cells": [
            "F1": registryCell(
                "function-1", "F1", "F1", "f1", "passthrough", "keyboard",
                iconKind: "sf-symbol"
            ),
        ],
    ]
    if includeFooter {
        yabaiLayer["footer"] = [
            "sections": [
                [
                    "id": "holds",
                    "title": "Homerow holds",
                    "columns": ["Keys", "Hold"],
                    "rows": [["C / H", "Control"], ["R / S", "Option"]],
                ],
            ],
        ]
    }
    let keyO: [String: Any] = [
        "position": "KeyO",
        "sourceKey": "o",
        "mineKey": "G",
        "width": 1.0,
    ]
    let keyboardRow: [[String: Any]] = [
        [
            "position": "KeyW",
            "sourceKey": "w",
            "mineKey": "L",
            "width": 1.0,
        ],
        [
            "position": "IntlBackslash",
            "sourceKey": "<",
            "namedKey": "Homerow Scroll",
            "badge": "Scroll",
            "width": 1.0,
        ],
        [
            "position": "KeyZ",
            "sourceKey": "y",
            "mineKey": "V",
            "width": 1.0,
        ],
        [
            "position": "KeyD",
            "sourceKey": "d",
            "mineKey": "I",
            "width": 1.0,
        ],
        [
            "position": "KeyS",
            "sourceKey": "s",
            "mineKey": "R",
            "width": 1.0,
        ],
        [
            "position": "KeyL",
            "sourceKey": "l",
            "mineKey": "S",
            "width": 1.0,
        ],
        [
            "position": "KeyY",
            "sourceKey": "z",
            "mineKey": "W",
            "width": 1.0,
        ],
        [
            "position": "KeyH",
            "sourceKey": "h",
            "mineKey": "M",
            "width": 1.0,
        ],
        keyO,
        namedKeyboardPosition("F1", "f1", "F1"),
        namedKeyboardPosition("ArrowUp", "up", "Up"),
        namedKeyboardPosition("ArrowLeft", "left", "Left"),
        namedKeyboardPosition("ArrowDown", "down", "Down"),
        namedKeyboardPosition("ArrowRight", "rght", "Right"),
    ]
    let arrowCluster: [String: Any] = [
        "up": namedKeyboardPosition("ArrowUp", "up", "Up"),
        "left": namedKeyboardPosition("ArrowLeft", "left", "Left"),
        "down": namedKeyboardPosition("ArrowDown", "down", "Down"),
        "right": namedKeyboardPosition("ArrowRight", "rght", "Right"),
    ]
    let defyThumbs: [String: Any] = [
        "label": "Defy thumbs",
        "left": [
            "top": [
                namedKeyboardPosition("F13", "f13", "F13"),
                namedKeyboardPosition("F14", "f14", "F14"),
                namedKeyboardPosition("F15", "f15", "F15"),
                namedKeyboardPosition("F16", "f16", "F16"),
            ],
            "bottom": [
                namedKeyboardPosition("Numpad0", "kp0", "Keypad 0"),
                namedKeyboardPosition("Numpad1", "kp1", "Keypad 1"),
                namedKeyboardPosition("Numpad2", "kp2", "Keypad 2"),
                namedKeyboardPosition("F17", "f17", "F17"),
            ],
        ],
        "right": [
            "top": [
                namedKeyboardPosition("F19", "f19", "F19"),
                namedKeyboardPosition("F20", "f20", "F20"),
                namedKeyboardPosition("F21", "f21", "F21"),
                namedKeyboardPosition("F22", "f22", "F22"),
            ],
            "bottom": [
                namedKeyboardPosition("F18", "f18", "F18"),
                namedKeyboardPosition("Numpad3", "kp3", "Keypad 3"),
                namedKeyboardPosition("Numpad4", "kp4", "Keypad 4"),
                namedKeyboardPosition("Numpad5", "kp5", "Keypad 5"),
            ],
        ],
    ]
    var geometry: [String: Any] = [
        "layoutId": "mine-iso",
        "rows": [keyboardRow],
        "arrowCluster": arrowCluster,
    ]
    if includeGeometryProfiles {
        let arrowPositionIDs = Set([
            "ArrowUp", "ArrowLeft", "ArrowDown", "ArrowRight",
        ])
        let defyMainPositions = [keyO] + keyboardRow.filter { position in
            guard let positionID = position["position"] as? String else { return false }
            return positionID != "KeyO" && !arrowPositionIDs.contains(positionID)
        }
        let splitIndex = (defyMainPositions.count + 1) / 2
        let makeDefyRows = {
            (positions: [[String: Any]], startsWithEmptySlot: Bool) -> [[Any]] in
            var remaining = positions
            return [7, 7, 7, 6].enumerated().map { rowIndex, count in
                (0..<count).map { slotIndex -> Any in
                    if startsWithEmptySlot && rowIndex == 0 && slotIndex == 0 {
                        return NSNull()
                    }
                    guard !remaining.isEmpty else { return NSNull() }
                    return remaining.removeFirst()
                }
            }
        }
        let leftRows = makeDefyRows(
            Array(defyMainPositions.prefix(splitIndex)),
            true
        )
        let rightRows = makeDefyRows(
            Array(defyMainPositions.dropFirst(splitIndex)),
            false
        )
        geometry["defaultProfileId"] = "macbook"
        geometry["profiles"] = [
            [
                "id": "macbook",
                "label": "MacBook",
                "kind": "macbook",
                "rows": [keyboardRow],
                "arrowCluster": arrowCluster,
            ],
            [
                "id": "defy",
                "label": "Dygma Defy",
                "kind": "defy",
                "halves": [
                    "left": [
                        "rows": leftRows,
                        "thumbs": defyThumbs["left"]!,
                    ],
                    "right": [
                        "rows": rightRows,
                        "thumbs": defyThumbs["right"]!,
                    ],
                ],
            ],
        ]
    } else {
        geometry["defyThumbs"] = defyThumbs
    }
    let payload: [String: Any] = [
        "schemaVersion": 1,
        "providers": [
            [
                "id": "macos-symbolic-hotkeys",
                "ownership": "enforced",
                "sourceLabel": "macOS Symbolic Hotkeys",
                "health": "ok",
                "diagnosticIds": [],
            ],
            [
                "id": "aerc",
                "ownership": "observed",
                "sourceLabel": "aerc bindings",
                "health": "ok",
                "diagnosticIds": [],
            ],
        ],
        "bindings": [
            [
                "id": "macos.spotlight",
                "provider": "macos-symbolic-hotkeys",
                "ownership": "enforced",
                "gesture": [
                    "type": "chord",
                    "key": "Space",
                    "modifiers": ["command"],
                    "display": "⌘ Space",
                    "position": "Space",
                    "sourceKey": "spc",
                    "displayKey": "Space",
                ],
                "context": ["stage": "system"],
                "action": ["id": "macos.spotlight", "label": "Spotlight"],
                "source": [
                    "path": "shared/keybindings/providers/macos-modifier-space.nix",
                    "target": "com.apple.symbolichotkeys:64",
                ],
                "tags": ["modifier-space", "system"],
                "diagnosticIds": [],
            ],
            [
                "id": "aerc.compose-review.send",
                "provider": "aerc",
                "ownership": "observed",
                "gesture": [
                    "type": "chord",
                    "key": "y",
                    "modifiers": [],
                    "display": "y",
                ],
                "context": [
                    "stage": "application",
                    "application": "aerc",
                    "mode": "compose::review",
                ],
                "action": [
                    "id": "aerc.compose-review.send",
                    "label": "Send",
                    "detail": ":send<Enter>",
                ],
                "source": [
                    "path": "darwin/home/config/aerc/binds.conf",
                    "line": 12,
                ],
                "tags": ["aerc", "compose-review"],
                "diagnosticIds": [],
            ],
        ],
        "diagnostics": [],
        "views": [
            "modifier-space": [
                "id": "modifier-space",
                "label": "Modifier + Space",
                "slots": slots,
            ],
            "all-bindings": [
                "id": "all-bindings",
                "label": "All Bindings",
                "bindingIds": ["aerc.compose-review.send", "macos.spotlight"],
            ],
            "explorer-default": [
                "id": "explorer-default",
                "label": "My Bindings",
                "bindingIds": ["macos.spotlight"],
            ],
            "keyboard-layers": [
                "id": "keyboard-layers",
                "label": "Keyboard Layers",
                "geometry": geometry,
                "layers": [
                    "mine": [
                        "id": "mine",
                        "label": "Mine",
                        "trigger": "manual",
                        "showBaseKeys": true,
                        "groups": [
                            ["id": "layers", "color": "#cba6f7"],
                        ],
                        "cells": [
                            "KeyW": registryCell(
                                "symbols", "Symbols", "L", "w", "layers", ":finder:",
                                withPresentation: true
                            ),
                            "KeyD": [
                                "bindingId": "test.nav-1",
                                "displayKey": "I",
                                "sourceKey": "d",
                                "actionLabel": "1 · Hold Command",
                                "group": "layers",
                                "presentation": [
                                    "primary": ["kind": "glyph", "token": "1"],
                                    "holdModifier": "command",
                                    "explanation": NSNull(),
                                ],
                            ],
                            "F14": registryCell(
                                "apps", "Space / Apps", "F14", "f14", "layers", ":finder:"
                            ),
                        ],
                    ],
                    "fn": [
                        "id": "fn",
                        "label": "Media · Brightness · F-Keys",
                        "trigger": "manual",
                        "groups": [
                            ["id": "functions", "color": "#f9e2af"],
                        ],
                        "cells": [
                            "ArrowUp": [
                                "bindingId": "test.arrow-hold",
                                "displayKey": "Up",
                                "sourceKey": "up",
                                "actionLabel": "Up · Hold Control",
                                "group": "functions",
                                "presentation": [
                                    "primary": ["kind": "sf-symbol", "token": "arrow.up"],
                                    "holdModifier": "control",
                                    "explanation": NSNull(),
                                ],
                            ],
                        ],
                    ],
                    "yabai": yabaiLayer,
                    "apps": [
                        "id": "apps",
                        "label": "Apps",
                        "trigger": "delay",
                        "overlayGroup": "apps",
                        "groups": [
                            ["id": "browse", "color": "#a6e3a1"],
                        ],
                        "cells": [
                            "KeyW": [
                                "bindingId": "macos.spotlight",
                                "displayKey": "L",
                                "sourceKey": "w",
                                "actionLabel": "Finder",
                                "group": "browse",
                                "icon": optionalFinderIcon,
                            ],
                            "IntlBackslash": [
                                "bindingId": "macos.spotlight",
                                "displayKey": "Homerow Scroll",
                                "sourceKey": "<",
                                "actionLabel": "Scroll",
                                "group": "browse",
                                "icon": [
                                    "kind": "sf-symbol",
                                    "token": "scroll",
                                ],
                            ],
                            "KeyO": registryCell(
                                "geometry", "MacBook / Defy", "G", "o", "browse",
                                "keyboard", iconKind: "sf-symbol"
                            ),
                        ],
                    ],
                    "apps-alt": [
                        "id": "apps-alt",
                        "label": "Alternate Apps",
                        "trigger": "delay",
                        "overlayGroup": "apps",
                        "groups": [
                            ["id": "browse", "color": "#a6e3a1"],
                            ["id": "chat", "color": "#fab387"],
                            ["id": "productivity", "color": "#89b4fa"],
                        ],
                        "cells": [
                            "KeyD": registryCell(
                                "chrome", "Chrome", "I", "d", "browse", ":google_chrome:"
                            ),
                            "KeyS": registryCell(
                                "acrobat", "Adobe Acrobat", "R", "s", "productivity", ":acrobat:"
                            ),
                            "KeyL": registryCell(
                                "signal", "Signal", "S", "l", "chat", ":signal:"
                            ),
                            "KeyY": registryCell(
                                "whatsapp", "WhatsApp", "W", "z", "chat", ":whats_app:"
                            ),
                            "KeyH": registryCell(
                                "messages", "Messages", "M", "h", "chat", ":messages:"
                            ),
                        ],
                    ],
                ],
            ],
        ],
    ]
    return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
}


@Suite("Keybinding Registry")
struct RegistryTests {
    @Test("decodes and projects explicit tap hold and explanation roles")
    func projectsExplicitPresentationRoles() throws {
        let literal = RegistryKeyVisual(kind: "glyph", token: "1")
        let expected = RegistryKeyPresentation(
            primary: literal,
            holdModifier: "command",
            explanation: nil
        )
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let mineLayer = try #require(registry.views.keyboardLayers?.layers["mine"])
        let mine = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "mine",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let digit = try #require(mine.key(at: "KeyD"))
        let symbols = try #require(mine.key(at: "KeyW"))

        #expect(mineLayer.cells["KeyD"]?.presentation == expected)
        #expect(digit.actionLabel == "1 · Hold Command")
        #expect(digit.primary == literal)
        #expect(digit.holdModifier == "command")
        #expect(digit.explanation == nil)
        #expect(
            symbols.primary
                == RegistryKeyVisual(kind: "app-font", token: ":finder:")
        )
        #expect(symbols.explanation == "Symbols")
    }

    @Test("schema one cells without presentation use legacy icon and label")
    func projectsLegacyPresentationFallback() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let alternateApps = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "apps-alt",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let chrome = try #require(alternateApps.key(at: "KeyD"))

        #expect(chrome.actionLabel == "Chrome")
        #expect(
            chrome.primary
                == RegistryKeyVisual(kind: "app-font", token: ":google_chrome:")
        )
        #expect(chrome.holdModifier == nil)
        #expect(chrome.explanation == "Chrome")
    }

    @Test("decodes registry version one")
    func decodesRegistry() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        #expect(registry.schemaVersion == 1)
        #expect(registry.views.modifierSpace.slots.count == 15)
        #expect(registry.bindings.count == 2)
    }

    @Test("decodes ISO keyboard layers and both icon kinds")
    func decodesKeyboardLayers() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let keyboardLayers = try #require(registry.views.keyboardLayers)
        let geometry = try #require(keyboardLayers.geometry)
        #expect(geometry.layoutId == "mine-iso")
        #expect(geometry.rows[0].contains { $0.position == "IntlBackslash" })
        let defyThumbs = try #require(geometry.defyThumbs)
        #expect(defyThumbs.left.top.map(\.position) == ["F13", "F14", "F15", "F16"])
        #expect(
            defyThumbs.left.bottom.map(\.position)
                == ["Numpad0", "Numpad1", "Numpad2", "F17"]
        )
        #expect(defyThumbs.right.top.map(\.position) == ["F19", "F20", "F21", "F22"])
        #expect(
            defyThumbs.right.bottom.map(\.position)
                == ["F18", "Numpad3", "Numpad4", "Numpad5"]
        )
        #expect(keyboardLayers.layers["mine"]?.showBaseKeys == true)
        #expect(
            keyboardLayers.layers["apps"]?.cells["KeyW"]?.icon
                == RegistryKeyIcon(kind: "app-font", token: ":finder:")
        )
        #expect(
            keyboardLayers.layers["apps"]?.cells["IntlBackslash"]?.icon
                == RegistryKeyIcon(kind: "sf-symbol", token: "scroll")
        )
        #expect(keyboardLayers.layers["apps"]?.overlayGroup == "apps")
        #expect(keyboardLayers.layers["apps-alt"]?.overlayGroup == "apps")
    }

    @Test("decodes ordered keyboard geometry profiles and nullable Defy slots")
    func decodesKeyboardGeometryProfiles() throws {
        let registry = try KeybindingRegistry.parse(
            from: versionOneFixtureData(includeGeometryProfiles: true)
        )
        let geometry = try #require(registry.views.keyboardLayers?.geometry)
        let profiles = try #require(geometry.profiles)

        #expect(geometry.defaultProfileId == "macbook")
        #expect(profiles.map(\.id) == ["macbook", "defy"])
        #expect(profiles.map(\.kind) == ["macbook", "defy"])
        let defy = profiles[1]
        #expect(defy.halves?.left.rows.map(\.count) == [7, 7, 7, 6])
        #expect(defy.halves?.right.rows.map(\.count) == [7, 7, 7, 6])
        #expect(defy.halves?.left.rows[0][0] == nil)
        #expect(defy.halves?.left.rows[0][1]?.position == "KeyO")
        #expect(defy.halves?.right.thumbs.top.count == 4)
        #expect(defy.halves?.right.thumbs.bottom.count == 4)
    }

    @Test("synthesizes one legacy profile when declared profiles are absent")
    func synthesizesLegacyKeyboardGeometryProfile() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let geometry = try #require(registry.views.keyboardLayers?.geometry)
        let profile = try #require(geometry.effectiveProfiles.first)

        #expect(geometry.effectiveProfiles.count == 1)
        #expect(profile.id == "legacy")
        #expect(profile.kind == "legacy")
        #expect(profile.rows?[0][0]?.position == "KeyW")
        #expect(profile.arrowCluster?.up.position == "ArrowUp")
        #expect(profile.halves == nil)
    }

    @Test("projects every layer with identical semantics at shared positions")
    func projectsIdenticalSemanticsAcrossProfiles() throws {
        let registry = try KeybindingRegistry.parse(
            from: versionOneFixtureData(includeGeometryProfiles: true)
        )
        let keyboardLayers = try #require(registry.views.keyboardLayers)
        let expectedSharedPositionIDs = Set([
            "KeyW", "IntlBackslash", "KeyZ", "KeyD", "KeyS",
            "KeyL", "KeyY", "KeyH", "KeyO", "F1",
        ])

        for layerName in keyboardLayers.layers.keys.sorted() {
            let macbook = try #require(
                KeyboardLayerProjector.presentation(
                    layerName: layerName,
                    legacyLayer: nil,
                    registry: registry,
                    showFree: false,
                    geometryProfileId: "macbook"
                )
            )
            let defy = try #require(
                KeyboardLayerProjector.presentation(
                    layerName: layerName,
                    legacyLayer: nil,
                    registry: registry,
                    showFree: false,
                    geometryProfileId: "defy"
                )
            )
            guard case .macbook = macbook.geometry else {
                Issue.record("Expected MacBook presentation for \(layerName)")
                return
            }
            guard case .defy = defy.geometry else {
                Issue.record("Expected Defy presentation for \(layerName)")
                return
            }
            let macbookKeys = Dictionary(
                uniqueKeysWithValues: macbook.geometry.allKeys.map { ($0.id, $0) }
            )
            let defyKeys = Dictionary(
                uniqueKeysWithValues: defy.geometry.allKeys.map { ($0.id, $0) }
            )
            let sharedPositionIDs = Set(macbookKeys.keys).intersection(defyKeys.keys)

            #expect(
                sharedPositionIDs == expectedSharedPositionIDs,
                "Unexpected shared positions for layer \(layerName)"
            )
            for positionID in sharedPositionIDs.sorted() {
                #expect(
                    macbookKeys[positionID] == defyKeys[positionID],
                    "Layer \(layerName) diverged at \(positionID)"
                )
            }
        }
    }

    @Test("projects compact badges and one separate arrow cluster")
    func projectsCompactBadgesAndArrowCluster() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let geometry = try #require(registry.views.keyboardLayers?.geometry)
        let scroll = try #require(
            geometry.rows.lazy.flatMap { $0 }.first { $0.position == "IntlBackslash" }
        )
        let mine = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "mine",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let cluster = try #require(mine.arrowCluster)

        #expect(scroll.namedKey == "Homerow Scroll")
        #expect(scroll.badge == "Scroll")
        #expect(mine.key(at: "IntlBackslash")?.badge == "Scroll")
        #expect(cluster.up.id == "ArrowUp")
        #expect(cluster.left.id == "ArrowLeft")
        #expect(cluster.down.id == "ArrowDown")
        #expect(cluster.right.id == "ArrowRight")
        #expect(
            Set(mine.rows.flatMap { $0 }.map(\.id)).isDisjoint(
                with: ["ArrowUp", "ArrowLeft", "ArrowDown", "ArrowRight"]
            )
        )
        #expect(mine.key(at: "ArrowUp") == cluster.up)
        #expect(mine.key(at: "ArrowLeft") == cluster.left)
        #expect(mine.key(at: "ArrowDown") == cluster.down)
        #expect(mine.key(at: "ArrowRight") == cluster.right)
    }

    @Test("maps visual roles and detects holds across keyboard regions")
    func mapsVisualRolesAndDetectsHolds() throws {
        #expect(KeyboardVisualSemantics.modifierGlyph("command") == "⌘")
        #expect(KeyboardVisualSemantics.modifierGlyph("shift") == "⇧")
        #expect(KeyboardVisualSemantics.modifierGlyph("option") == "⌥")
        #expect(KeyboardVisualSemantics.modifierGlyph("control") == "⌃")
        #expect(KeyboardVisualSemantics.modifierGlyph("unknown") == nil)
        #expect(KeyboardVisualSemantics.glyphScale(";") == .single)
        #expect(KeyboardVisualSemantics.glyphScale("F12") == .compact)

        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let mine = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "mine",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let function = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "fn",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let alternateApps = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "apps-alt",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )

        #expect(mine.hasHoldModifiers)
        #expect(function.rows.flatMap { $0 }.allSatisfy { $0.holdModifier == nil })
        #expect(function.arrowCluster?.up.holdModifier == "control")
        #expect(function.hasHoldModifiers)
        #expect(!alternateApps.hasHoldModifiers)
    }

    @Test("projects an iconless mapped cell with its label and color")
    func projectsIconlessMappedCell() throws {
        let registry = try KeybindingRegistry.parse(
            from: versionOneFixtureData(includeIconlessCell: true)
        )
        let apps = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "apps",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let finder = try #require(apps.key(at: "KeyW"))

        #expect(finder.actionLabel == "Finder")
        #expect(finder.colorHex == "#a6e3a1")
        #expect(finder.primary == nil)
    }

    @Test("decodes and projects optional layer footer")
    func decodesAndProjectsLayerFooter() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let layer = try #require(registry.views.keyboardLayers?.layers["yabai"])
        let section = try #require(layer.footer?.sections.first)

        #expect(section.id == "holds")
        #expect(section.title == "Homerow holds")
        #expect(section.columns == ["Keys", "Hold"])
        #expect(section.rows == [["C / H", "Control"], ["R / S", "Option"]])

        let presentation = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "yabai",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        #expect(presentation.footer == layer.footer)
    }

    @Test("decodes schema one layer without optional footer")
    func decodesLayerWithoutFooter() throws {
        let registry = try KeybindingRegistry.parse(
            from: versionOneFixtureData(includeFooter: false)
        )
        let layer = try #require(registry.views.keyboardLayers?.layers["yabai"])
        #expect(layer.footer == nil)
    }

    @Test("projects all alternate apps from the registry")
    func projectsAlternateApps() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let alternateApps = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "apps-alt",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )

        #expect(alternateApps.label == "Alternate Apps")
        #expect(alternateApps.key(at: "KeyD")?.actionLabel == "Chrome")
        #expect(alternateApps.key(at: "KeyS")?.actionLabel == "Adobe Acrobat")
        #expect(alternateApps.key(at: "KeyL")?.actionLabel == "Signal")
        #expect(alternateApps.key(at: "KeyY")?.actionLabel == "WhatsApp")
        #expect(alternateApps.key(at: "KeyH")?.actionLabel == "Messages")
    }

    @Test("base presentation fills Mine labels and keeps semantic actions")
    func projectsBaseKeysAndActions() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let mine = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "mine",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )

        let empty = try #require(mine.key(at: "KeyZ"))
        #expect(empty.badge == "V")
        #expect(empty.keyLabel == nil)
        #expect(empty.actionLabel == nil)
        #expect(empty.primary == nil)

        let mapped = try #require(mine.key(at: "KeyW"))
        #expect(mapped.badge == "L")
        #expect(mapped.keyLabel == nil)
        #expect(mapped.actionLabel == "Symbols")
        #expect(mapped.primary == RegistryKeyVisual(kind: "app-font", token: ":finder:"))
    }

    @Test("projects passthrough keys quietly and omits their legend group")
    func projectsPassthroughQuietly() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let yabai = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "yabai",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let f1 = try #require(yabai.key(at: "F1"))

        #expect(f1.badge == "F1")
        #expect(f1.keyLabel == nil)
        #expect(f1.actionLabel == nil)
        #expect(f1.primary == nil)
        #expect(f1.colorHex == nil)
        #expect(yabai.groups.map(\.id) == ["windows"])
    }

    @Test("projects Defy thumbs in checked physical order")
    func projectsDefyThumbs() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let mine = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "mine",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let thumbs = try #require(mine.defyThumbs)

        #expect(thumbs.leftTop.map(\.id) == ["F13", "F14", "F15", "F16"])
        #expect(thumbs.leftBottom.map(\.id) == ["Numpad0", "Numpad1", "Numpad2", "F17"])
        #expect(thumbs.rightTop.map(\.id) == ["F19", "F20", "F21", "F22"])
        #expect(thumbs.rightBottom.map(\.id) == ["F18", "Numpad3", "Numpad4", "Numpad5"])
        #expect(thumbs.leftTop[1].badge == "F14")
        #expect(thumbs.leftTop[1].actionLabel == "Space / Apps")
        #expect(mine.key(at: "F14") == thumbs.leftTop[1])
    }

    @Test("search covers gesture action context tags and source")
    func searchCoversAllFields() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        #expect(
            RegistryQuery(search: "spotlight").filter(registry).map(\.id)
                == ["macos.spotlight"]
        )
        #expect(
            RegistryQuery(search: "compose::review").filter(registry).map(\.id)
                == ["aerc.compose-review.send"]
        )
        #expect(
            RegistryQuery(search: "binds.conf").filter(registry).map(\.id)
                == ["aerc.compose-review.send"]
        )
    }

    @Test("provider and ownership filters compose")
    func filtersCompose() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let query = RegistryQuery(provider: "aerc", ownership: "observed")
        #expect(query.filter(registry).map(\.id) == ["aerc.compose-review.send"])
    }

    @Test("Explorer defaults to its projection while search remains global")
    func explorerProjectionAndGlobalSearch() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let defaultIDs = Set(try #require(registry.views.explorerDefault).bindingIds)

        #expect(
            RegistryQuery().filter(registry, defaultBindingIDs: defaultIDs).map(\.id)
                == ["macos.spotlight"]
        )
        #expect(
            RegistryQuery(search: "send")
                .filter(registry, defaultBindingIDs: defaultIDs)
                .map(\.id)
                == ["aerc.compose-review.send"]
        )
    }

    @Test("registry layers replace matching legacy layers only")
    func registryLayersOverrideMatchingLegacyLayers() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let apps = KeyboardLayerProjector.presentation(
            layerName: "apps",
            legacyLayer: Config.Layer(label: "Legacy Apps"),
            registry: registry,
            showFree: false
        )
        let navigation = KeyboardLayerProjector.presentation(
            layerName: "nav",
            legacyLayer: Config.Layer(label: "Navigation"),
            registry: registry,
            showFree: false
        )

        #expect(apps?.label == "Apps")
        #expect(apps?.source == .registry)
        #expect(navigation?.label == "Navigation")
        #expect(navigation?.source == .legacy)
    }

    @Test("occupied-only and show-free projections use mine badges")
    func projectsOccupiedAndFreeKeys() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        let occupied = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "apps",
                legacyLayer: nil,
                registry: registry,
                showFree: false
            )
        )
        let showFree = try #require(
            KeyboardLayerProjector.presentation(
                layerName: "apps",
                legacyLayer: nil,
                registry: registry,
                showFree: true
            )
        )
        let occupiedL = try #require(occupied.key(at: "KeyW"))
        let occupiedV = try #require(occupied.key(at: "KeyZ"))
        let freeV = try #require(showFree.key(at: "KeyZ"))

        #expect(occupiedL.badge == "L")
        #expect(occupiedL.keyLabel == nil)
        #expect(occupiedL.actionLabel == "Finder")
        #expect(
            occupiedL.primary
                == RegistryKeyVisual(kind: "app-font", token: ":finder:")
        )
        #expect(occupiedV.badge == nil)
        #expect(occupiedV.freeLabel == nil)
        #expect(freeV.badge == "V")
        #expect(freeV.freeLabel == "Free")
    }

    @Test("invalid schema reports concrete version")
    func rejectsUnknownSchema() {
        let data = Data(#"{"schemaVersion":2}"#.utf8)
        #expect(throws: RegistryLoadError.unsupportedSchema(2)) {
            try KeybindingRegistry.parse(from: data)
        }
    }

    @Test("missing file reports its path")
    func missingFileReportsPath() {
        let path = "/tmp/kanata-cheatsheet-does-not-exist/registry.json"
        do {
            _ = try KeybindingRegistry.load(from: path)
            Issue.record("Expected the missing registry to fail")
        } catch let error as RegistryLoadError {
            #expect(error.description.contains(path))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
