import SwiftUI


@available(macOS 14, *)
struct ModifierSpaceLegend: View {
    let slots: [ModifierSpaceSlot]
    let registry: KeybindingRegistry
    let showFree: Bool

    private var visibleSlots: [ModifierSpaceSlot] {
        showFree ? slots : slots.filter { !$0.isFree }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MODIFIER + SPACE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#cba6f7"))
                    .tracking(2)
                Spacer()
                Text(showFree ? "Fn  Occupied only" : "Fn  Show free")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "#6c7086"))
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 116, maximum: 180), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(visibleSlots) { slot in
                    ModifierSpaceCell(
                        slot: slot,
                        actionLabels: slot.bindingIds.compactMap {
                            registry.binding(withID: $0)?.action.label
                        }
                    )
                }
            }
        }
        .padding(.top, 2)
    }
}


@available(macOS 14, *)
private struct ModifierSpaceCell: View {
    let slot: ModifierSpaceSlot
    let actionLabels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(slot.display)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(slot.isFree ? Color(hex: "#585b70") : Color(hex: "#cba6f7"))
            Text(slot.isFree ? "Free" : actionLabels.joined(separator: " · "))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(slot.isFree ? Color(hex: "#45475a") : Color(hex: "#bac2de"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    slot.isFree
                        ? Color(hex: "#313244").opacity(0.24)
                        : Color(hex: "#cba6f7").opacity(0.10)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    slot.isFree
                        ? Color(hex: "#cdd6f4").opacity(0.03)
                        : Color(hex: "#cba6f7").opacity(0.18),
                    lineWidth: 1
                )
        )
    }
}
