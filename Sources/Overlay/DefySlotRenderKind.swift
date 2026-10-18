import Foundation


enum DefySlotRenderKind: Equatable {
    case vacancy
    case quiet(firmwareKey: String)
    case key(KeyboardPresentedKey)
    case inputPath(KeyboardPresentedDefySlot)

    init(
        slot: KeyboardPresentedDefySlot?,
        showInputPath: Bool = false
    ) {
        guard let slot else {
            self = .vacancy
            return
        }
        guard !showInputPath else {
            self = .inputPath(slot)
            return
        }
        guard let key = slot.key else {
            self = .quiet(firmwareKey: slot.firmwareKey)
            return
        }
        self = .key(key)
    }

    var isVacancy: Bool {
        if case .vacancy = self { return true }
        return false
    }
}
