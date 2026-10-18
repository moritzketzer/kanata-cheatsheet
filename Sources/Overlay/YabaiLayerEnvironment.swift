import SwiftUI


private struct YabaiLayerEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}


extension EnvironmentValues {
    var isYabaiLayer: Bool {
        get { self[YabaiLayerEnvironmentKey.self] }
        set { self[YabaiLayerEnvironmentKey.self] = newValue }
    }
}
