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
