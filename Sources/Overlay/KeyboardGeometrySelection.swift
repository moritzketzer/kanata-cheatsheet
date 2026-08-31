struct KeyboardGeometrySelection: Equatable {
    static let defaultsKey = "local.kanata-cheatsheet.keyboardGeometryProfileId"

    let profileIds: [String]
    let defaultProfileId: String?
    private(set) var selectedProfileId: String?

    init(
        geometry: RegistryKeyboardGeometry?,
        storedProfileId: String?
    ) {
        let availableProfileIds = geometry?.effectiveProfiles.map(\.id) ?? []
        profileIds = availableProfileIds
        let declaredDefault = geometry?.defaultProfileId
        defaultProfileId = declaredDefault.flatMap {
            availableProfileIds.contains($0) ? $0 : nil
        }
        if let storedProfileId, availableProfileIds.contains(storedProfileId) {
            selectedProfileId = storedProfileId
        } else {
            selectedProfileId = defaultProfileId ?? availableProfileIds.first
        }
    }

    mutating func toggle() -> String? {
        guard profileIds.count > 1,
              let selectedProfileId,
              let index = profileIds.firstIndex(of: selectedProfileId)
        else { return nil }

        let next = profileIds[(index + 1) % profileIds.count]
        self.selectedProfileId = next
        return next
    }

    mutating func select(_ profileId: String) -> String? {
        guard profileIds.contains(profileId), profileId != selectedProfileId else {
            return nil
        }
        selectedProfileId = profileId
        return profileId
    }
}
