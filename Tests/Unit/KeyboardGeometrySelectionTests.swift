import Foundation
import Testing


private func geometryForSelection() -> RegistryKeyboardGeometry {
    RegistryKeyboardGeometry(
        layoutId: "mine-iso",
        rows: [],
        defaultProfileId: "macbook",
        profiles: [
            RegistryKeyboardGeometryProfile(
                id: "macbook",
                label: "MacBook",
                kind: "macbook"
            ),
            RegistryKeyboardGeometryProfile(
                id: "defy",
                label: "Dygma Defy",
                kind: "defy"
            ),
        ]
    )
}


@Suite("Keyboard Geometry Selection")
struct KeyboardGeometrySelectionTests {
    @Test("starts at the declared default and follows registry order")
    func startsAtDefaultAndTogglesInOrder() {
        var selection = KeyboardGeometrySelection(
            geometry: geometryForSelection(),
            storedProfileId: nil
        )

        #expect(selection.profileIds == ["macbook", "defy"])
        #expect(selection.defaultProfileId == "macbook")
        #expect(selection.selectedProfileId == "macbook")
        #expect(selection.toggle() == "defy")
        #expect(selection.toggle() == "macbook")
    }

    @Test("restores a valid profile and repairs an invalid profile")
    func restoresAndRepairsStoredProfile() {
        let restored = KeyboardGeometrySelection(
            geometry: geometryForSelection(),
            storedProfileId: "defy"
        )
        let repaired = KeyboardGeometrySelection(
            geometry: geometryForSelection(),
            storedProfileId: "removed-profile"
        )

        #expect(restored.selectedProfileId == "defy")
        #expect(repaired.selectedProfileId == "macbook")
    }

    @Test("legacy and missing geometry do not toggle")
    func legacyAndMissingGeometryDoNotToggle() {
        var legacy = KeyboardGeometrySelection(
            geometry: RegistryKeyboardGeometry(layoutId: "mine-iso", rows: []),
            storedProfileId: nil
        )
        var missing = KeyboardGeometrySelection(
            geometry: nil,
            storedProfileId: nil
        )

        #expect(legacy.selectedProfileId == "legacy")
        #expect(legacy.toggle() == nil)
        #expect(missing.selectedProfileId == nil)
        #expect(missing.toggle() == nil)
    }
}
