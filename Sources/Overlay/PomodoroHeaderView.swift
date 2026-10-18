import SwiftUI


@available(macOS 14, *)
struct PomodoroHeaderView: View {
    let title: String
    let status: PomodoroStatus?
    let width: CGFloat

    var statusLine: String {
        status?.statusLine ?? "Timerstatus nicht verfügbar"
    }

    var progressLine: String {
        status?.progressLine ?? "Tagesziel Dissertation: 30 Minuten"
    }

    var body: some View {
        VStack(spacing: 5) {
            LayerTitleText(label: title)

            Text(statusLine)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(status == nil ? Palette.overlay0 : Palette.text)
                .frame(height: 16)

            Text(progressLine)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(status == nil ? Palette.overlay0 : Palette.subtext1)
                .frame(height: 14)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: width)
    }
}
