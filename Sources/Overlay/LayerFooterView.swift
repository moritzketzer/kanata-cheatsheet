import SwiftUI


@available(macOS 14, *)
struct LayerFooterView: View {
    let footer: RegistryLayerFooter
    let availableWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(footer.sections) { section in
                LayerFooterSectionView(section: section)
            }
        }
        .frame(width: availableWidth, alignment: .leading)
    }
}


@available(macOS 14, *)
private struct LayerFooterSectionView: View {
    let section: RegistryLayerFooterSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: "#bac2de"))

            if section.id == "global-actions" {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.first ?? "")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#cba6f7"))
                            Text(row.dropFirst().first ?? "")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(hex: "#bac2de"))
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "#cba6f7").opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: "#cba6f7").opacity(0.18), lineWidth: 1)
                        )
                    }
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                    GridRow {
                        ForEach(Array(section.columns.enumerated()), id: \.offset) { _, column in
                            cell(column, weight: .semibold, color: Color(hex: "#cba6f7"))
                        }
                    }
                    ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                                cell(value, weight: .regular, color: Color(hex: "#6c7086"))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ value: String, weight: Font.Weight, color: Color) -> some View {
        Text(value)
            .font(.system(size: 10, weight: weight, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
