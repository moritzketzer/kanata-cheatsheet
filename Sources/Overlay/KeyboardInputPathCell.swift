import SwiftUI


@available(macOS 14, *)
struct KeyboardInputPathCell: View {
    let slot: KeyboardPresentedDefySlot
    let width: CGFloat
    let height: CGFloat
    var isThumb: Bool = false

    var referenceKeySize: CGFloat? = nil

    var primaryFontSize: CGFloat {
        (referenceKeySize ?? height) * KeyboardGeometryMetrics.inputPathFontFactor
    }

    private var labels: KeyboardInputPathLabels {
        KeyboardInputPathLabels.resolve(slot)
    }

    private var accessibilityText: String {
        if labels.isDeviceLocal {
            return "Firmware \(labels.firmware), device local"
        }
        return [
            "Firmware \(labels.firmware)",
            labels.source.map { "Kanata source \($0)" },
            labels.mine.map { "Mine \($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    var fillColor: Color { Palette.mauve.opacity(0.12) }
    var strokeColor: Color { Palette.mauve.opacity(0.24) }

    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 6).fill(fillColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: 1))
    }

    var content: some View {
        VStack(spacing: isThumb ? 0 : primaryFontSize * 0.30) {
            Text(labels.firmware)
                .foregroundStyle(Palette.subtext0)
            Text(labels.source ?? "-")
                .foregroundStyle(labels.source == nil ? Palette.subtext0 : Palette.text)
            Text(labels.mine ?? "-")
                .foregroundStyle(Palette.mauve)
                .fontWeight(.semibold)
        }
        .font(.system(size: primaryFontSize))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        // The inner frame insets the text 3 pt per side on a main key; the
        // outer one restores the slot's full layout size.
        .frame(width: width - (isThumb ? 0 : 6), height: height)
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}
