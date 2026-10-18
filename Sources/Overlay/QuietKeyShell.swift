import SwiftUI


@available(macOS 14, *)
struct QuietKeyShell: View {
    let label: String
    let width: CGFloat
    let height: CGFloat

    var fillColor: Color { Palette.surface0.opacity(0.22) }
    var strokeColor: Color { Palette.text.opacity(0.045) }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: 1))
            .overlay(content)
            .frame(width: width, height: height)
    }

    var content: some View {
        Text(label)
            .font(.system(size: height * 0.18, weight: .semibold))
            .foregroundStyle(Palette.text.opacity(0.78))
            .lineLimit(2)
            .minimumScaleFactor(0.55)
            .multilineTextAlignment(.center)
            .padding(4)
            .frame(width: width, height: height)
    }
}
