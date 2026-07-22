import Foundation


struct RegistryQuery: Equatable {
    var search = ""
    var provider: String?
    var application: String?
    var mode: String?
    var layer: String?
    var ownership: String?
    var diagnosticsOnly = false

    func filter(_ registry: KeybindingRegistry) -> [RegistryBinding] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return registry.bindings
            .filter { binding in
                if let provider, binding.provider != provider { return false }
                if let application, binding.context.application != application { return false }
                if let mode, binding.context.mode != mode { return false }
                if let layer, binding.context.layer != layer { return false }
                if let ownership, binding.ownership != ownership { return false }
                if diagnosticsOnly, binding.diagnosticIds.isEmpty { return false }
                if !needle.isEmpty, !searchableText(for: binding).contains(needle) {
                    return false
                }
                return true
            }
            .sorted(by: bindingOrder)
    }

    private func searchableText(for binding: RegistryBinding) -> String {
        [
            binding.id,
            binding.gesture.display,
            binding.action.label,
            binding.action.detail,
            binding.provider,
            binding.ownership,
            binding.context.stage,
            binding.context.application,
            binding.context.mode,
            binding.context.layer,
            binding.context.device,
            binding.source.path,
            binding.source.target,
            binding.tags.joined(separator: " "),
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    private func bindingOrder(_ left: RegistryBinding, _ right: RegistryBinding) -> Bool {
        let labelOrder = left.action.label.localizedCaseInsensitiveCompare(right.action.label)
        if labelOrder != .orderedSame { return labelOrder == .orderedAscending }
        let gestureOrder = left.gesture.display.localizedCaseInsensitiveCompare(right.gesture.display)
        if gestureOrder != .orderedSame { return gestureOrder == .orderedAscending }
        return left.id < right.id
    }
}
