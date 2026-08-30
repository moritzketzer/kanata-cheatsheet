import Foundation
import Testing


private func registryCell(
    _ id: String,
    _ label: String,
    _ displayKey: String,
    _ sourceKey: String,
    _ group: String,
    _ iconToken: String,
    iconKind: String = "app-font"
) -> [String: Any] {
    [
        "bindingId": "test.\(id)",
        "displayKey": displayKey,
        "sourceKey": sourceKey,
        "actionLabel": label,
        "group": group,
        "icon": ["kind": iconKind, "token": iconToken],
    ]
}


private func namedKeyboardPosition(
    _ position: String,
    _ sourceKey: String,
    _ namedKey: String
) -> [String: Any] {
    [
        "position": position,
        "sourceKey": sourceKey,
        "namedKey": namedKey,
        "width": 1.0,
    ]
}


private func presentedKey(
    _ actionLabel: String?,
    iconKind: String? = "sf-symbol",
    iconToken: String? = nil
) -> KeyboardPresentedKey {
    KeyboardPresentedKey(
        id: "KeyW",
        width: 1.0,
        badge: "L",
        actionLabel: actionLabel,
        freeLabel: nil,
        colorHex: "#f9e2af",
        icon: iconKind.flatMap { kind in
            iconToken.map { RegistryKeyIcon(kind: kind, token: $0) }
        }
    )
}


private func versionOneFixtureData(
    includeFooter: Bool = true,
    includeIconlessCell: Bool = false
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
                "geometry": [
                    "layoutId": "mine-iso",
                    "rows": [
                        [
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
                            namedKeyboardPosition("F1", "f1", "F1"),
                        ],
                    ],
                    "defyThumbs": [
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
                    ],
                ],
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
                                "symbols", "Symbols", "L", "w", "layers", ":finder:"
                            ),
                            "F14": registryCell(
                                "apps", "Space / Apps", "F14", "f14", "layers", ":finder:"
                            ),
                        ],
                    ],
                    "fn": [
                        "id": "fn",
                        "label": "Media · Brightness · F-Keys",
                        "trigger": "manual",
                        "groups": [],
                        "cells": [:],
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
    @Test("hides exact literal SF Symbol labels without dropping semantic data")
    func hidesExactLiteralLabels() {
        let digit = presentedKey("4", iconToken: "4.square")

        #expect(digit.actionLabel == "4")
        #expect(digit.displayActionLabel == nil)
        #expect(presentedKey("$", iconToken: "dollarsign.square").displayActionLabel == nil)
        #expect(presentedKey("−", iconToken: "minus.square").displayActionLabel == nil)
        #expect(presentedKey("-", iconToken: "minus.square").displayActionLabel == nil)
    }

    @Test("keeps labels that add meaning or lack a known literal icon")
    func keepsInformativeLabels() {
        #expect(
            presentedKey("1 · Hold Command", iconToken: "1.square").displayActionLabel
                == "1 · Hold Command"
        )
        #expect(presentedKey(";", iconKind: nil).displayActionLabel == ";")
        #expect(presentedKey("Copy", iconToken: "doc.on.doc").displayActionLabel == "Copy")
        #expect(
            presentedKey("Finder", iconKind: "app-font", iconToken: ":finder:")
                .displayActionLabel == "Finder"
        )
        #expect(
            presentedKey("Future", iconToken: "future.literal.symbol").displayActionLabel
                == "Future"
        )
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
        #expect(finder.icon == nil)
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
        #expect(empty.icon == nil)

        let mapped = try #require(mine.key(at: "KeyW"))
        #expect(mapped.badge == "L")
        #expect(mapped.keyLabel == nil)
        #expect(mapped.actionLabel == "Symbols")
        #expect(mapped.icon == RegistryKeyIcon(kind: "app-font", token: ":finder:"))
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
        #expect(f1.icon == nil)
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
        #expect(occupiedL.icon == RegistryKeyIcon(kind: "app-font", token: ":finder:"))
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
