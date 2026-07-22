import Foundation


enum RegistryLoadError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case unreadable(path: String, message: String)
    case invalid(path: String?, message: String)

    var description: String {
        switch self {
        case .unsupportedSchema(let version):
            return "Unsupported keybinding registry schema version: \(version)"
        case .unreadable(let path, let message):
            return "Could not read keybinding registry at \(path): \(message)"
        case .invalid(let path, let message):
            if let path {
                return "Invalid keybinding registry at \(path): \(message)"
            }
            return "Invalid keybinding registry: \(message)"
        }
    }
}


struct KeybindingRegistry: Codable, Hashable {
    let schemaVersion: Int
    let providers: [RegistryProvider]
    let bindings: [RegistryBinding]
    let diagnostics: [RegistryDiagnostic]
    let views: RegistryViews

    private struct VersionEnvelope: Decodable {
        let schemaVersion: Int
    }

    static func parse(from data: Data) throws -> KeybindingRegistry {
        let decoder = JSONDecoder()
        let version: VersionEnvelope
        do {
            version = try decoder.decode(VersionEnvelope.self, from: data)
        } catch {
            throw RegistryLoadError.invalid(path: nil, message: String(describing: error))
        }
        guard version.schemaVersion == 1 else {
            throw RegistryLoadError.unsupportedSchema(version.schemaVersion)
        }
        do {
            return try decoder.decode(KeybindingRegistry.self, from: data)
        } catch {
            throw RegistryLoadError.invalid(path: nil, message: String(describing: error))
        }
    }

    static func load(from path: String = defaultPath()) throws -> KeybindingRegistry {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw RegistryLoadError.unreadable(path: path, message: error.localizedDescription)
        }
        do {
            return try parse(from: data)
        } catch RegistryLoadError.invalid(_, let message) {
            throw RegistryLoadError.invalid(path: path, message: message)
        }
    }

    static func defaultPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/kanata-cheatsheet/registry.json"
    }

    func binding(withID id: String) -> RegistryBinding? {
        bindings.first { $0.id == id }
    }

    func diagnostic(withID id: String) -> RegistryDiagnostic? {
        diagnostics.first { $0.id == id }
    }
}


struct RegistryProvider: Codable, Hashable, Identifiable {
    let id: String
    let ownership: String
    let sourceLabel: String
    let health: String
    let diagnosticIds: [String]
}


struct RegistryBinding: Codable, Hashable, Identifiable {
    let id: String
    let provider: String
    let ownership: String
    let gesture: RegistryGesture
    let context: RegistryContext
    let action: RegistryAction
    let source: RegistrySource
    let tags: [String]
    let diagnosticIds: [String]
}


struct RegistryGesture: Codable, Hashable {
    let type: String
    let key: String
    let modifiers: [String]
    let display: String
    let prefixKey: String?
}


struct RegistryContext: Codable, Hashable {
    let stage: String
    let application: String?
    let mode: String?
    let layer: String?
    let device: String?
}


struct RegistryAction: Codable, Hashable {
    let id: String
    let label: String
    let detail: String?
}


struct RegistrySource: Codable, Hashable {
    let path: String
    let target: String?
    let line: Int?
}


struct RegistryDiagnostic: Codable, Hashable, Identifiable {
    let id: String
    let severity: String
    let code: String
    let message: String
    let relatedBindingIds: [String]
}


struct RegistryViews: Codable, Hashable {
    let modifierSpace: ModifierSpaceView
    let allBindings: AllBindingsView

    enum CodingKeys: String, CodingKey {
        case modifierSpace = "modifier-space"
        case allBindings = "all-bindings"
    }
}


struct ModifierSpaceView: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let slots: [ModifierSpaceSlot]
}


struct ModifierSpaceSlot: Codable, Hashable, Identifiable {
    var id: String { display }

    let modifiers: [String]
    let display: String
    let state: String
    let bindingIds: [String]

    var isFree: Bool { state == "free" }
}


struct AllBindingsView: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let bindingIds: [String]
}
