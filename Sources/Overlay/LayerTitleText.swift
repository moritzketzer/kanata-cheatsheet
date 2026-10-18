import SwiftUI


/// The one layer headline style, shared by the plain, Yabai, and Pomodoro
/// headers.
@available(macOS 14, *)
struct LayerTitleText: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.mauve)
            .tracking(4)
            .textCase(.uppercase)
    }
}
