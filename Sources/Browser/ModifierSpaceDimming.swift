import Foundation


/// Opacity decision for the bindings on a modifier-space card, kept free of
/// SwiftUI so the search cases stay unit-testable.
enum ModifierSpaceDimming {
    /// While a search is active, a binding it does not match dims — including
    /// when the search matches nothing at all. No search dims nothing.
    static func isDimmed(
        bindingID: String,
        search: String,
        matchingBindingIDs: Set<String>
    ) -> Bool {
        // Same trimming as `RegistryQuery`, so "search active" means the same
        // thing here as it does for the filter that produced the matches.
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        return !matchingBindingIDs.contains(bindingID)
    }
}
