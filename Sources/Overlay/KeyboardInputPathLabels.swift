import Foundation


struct KeyboardInputPathLabels: Equatable {
    static let caption = "FIRMWARE -> KANATA SOURCE -> MINE"
    /// Longer presentation labels fall back to the compact badge.
    static let maxMineLabelLength = 20

    let firmware: String
    let source: String?
    let mine: String?
    let isDeviceLocal: Bool

    static func resolve(
        _ slot: KeyboardPresentedDefySlot
    ) -> KeyboardInputPathLabels {
        guard let key = slot.key else {
            return KeyboardInputPathLabels(
                firmware: slot.firmwareKey,
                source: nil,
                mine: nil,
                isDeviceLocal: true
            )
        }

        let tap = tapLabel(for: key, mineKey: slot.mineKey)
        return KeyboardInputPathLabels(
            firmware: slot.firmwareKey,
            source: slot.sourceKey,
            mine: slot.mineDisabled ? nil : tap,
            isDeviceLocal: false
        )
    }

    private static func tapLabel(
        for key: KeyboardPresentedKey,
        mineKey: String?
    ) -> String? {
        if let mineKey { return mineKey }

        let presentationLabel = key.explanation
            ?? key.primary?.token
            ?? key.keyLabel
            ?? key.actionLabel
            ?? key.badge
        guard let label = presentationLabel else { return nil }

        // Dedicated Mouse keys only select a layer while held; they have no tap.
        if label == "Mouse" { return nil }
        if label.count > maxMineLabelLength, let badge = key.badge {
            return badge
        }
        return label.components(separatedBy: " / ")[0]
    }
}
