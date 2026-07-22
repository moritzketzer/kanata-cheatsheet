import Foundation
import Testing


private func versionOneFixtureData() throws -> Data {
    let slots: [[String: Any]] = (1...15).map { index in
        [
            "modifiers": index == 1 ? ["control"] : ["command"],
            "display": index == 1 ? "⌃ Space" : "⌘ Space",
            "state": index == 1 ? "free" : "occupied",
            "bindingIds": index == 1 ? [] : ["macos.spotlight"],
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
        ],
    ]
    return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
}


@Suite("Keybinding Registry")
struct RegistryTests {
    @Test("decodes registry version one")
    func decodesRegistry() throws {
        let registry = try KeybindingRegistry.parse(from: versionOneFixtureData())
        #expect(registry.schemaVersion == 1)
        #expect(registry.views.modifierSpace.slots.count == 15)
        #expect(registry.bindings.count == 2)
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
