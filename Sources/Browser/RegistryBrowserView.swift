import SwiftUI


private enum RegistrySidebarSelection: Hashable {
    case all
    case modifierSpace
    case diagnostics
    case freeModifierSpace
    case provider(String)
    case application(String)
    case mode(String)
    case layer(String)
}


private enum RegistryViewMode: String, CaseIterable, Identifiable {
    case list = "List"
    case keyboard = "Keyboard"

    var id: String { rawValue }
}


@available(macOS 14, *)
struct RegistryBrowserView: View {
    let registry: KeybindingRegistry?
    let loadError: String?

    @State private var sidebarSelection: RegistrySidebarSelection = .all
    @State private var search = ""
    @State private var ownership = "all"
    @State private var diagnosticsOnly = false
    @State private var viewMode: RegistryViewMode = .list
    @State private var selectedBindingID: String?

    init(registryResult: Result<KeybindingRegistry, Error>) {
        switch registryResult {
        case .success(let registry):
            self.registry = registry
            self.loadError = nil
        case .failure(let error):
            self.registry = nil
            self.loadError = String(describing: error)
        }
    }

    var body: some View {
        if let registry {
            NavigationSplitView {
                sidebar(registry)
            } detail: {
                browser(registry)
            }
        } else {
            RegistryLoadErrorView(message: loadError ?? "Unknown registry error")
        }
    }

    private func sidebar(_ registry: KeybindingRegistry) -> some View {
        List(selection: $sidebarSelection) {
            Section("Registry") {
                Label("All Bindings", systemImage: "list.bullet")
                    .tag(RegistrySidebarSelection.all)
                Label("Modifier + Space", systemImage: "keyboard")
                    .tag(RegistrySidebarSelection.modifierSpace)
                Label("Diagnostics", systemImage: "exclamationmark.triangle")
                    .tag(RegistrySidebarSelection.diagnostics)
                Label("Free Modifier + Space", systemImage: "square.dashed")
                    .tag(RegistrySidebarSelection.freeModifierSpace)
            }

            Section("Providers") {
                ForEach(registry.providers) { provider in
                    Label(provider.sourceLabel, systemImage: providerIcon(provider.id))
                        .tag(RegistrySidebarSelection.provider(provider.id))
                }
            }

            if !applications(registry).isEmpty {
                Section("Applications") {
                    ForEach(applications(registry), id: \.self) { application in
                        Label(application, systemImage: "app")
                            .tag(RegistrySidebarSelection.application(application))
                    }
                }
            }

            if !modes(registry).isEmpty {
                Section("Contexts") {
                    ForEach(modes(registry), id: \.self) { mode in
                        Label(mode, systemImage: "rectangle.3.group")
                            .tag(RegistrySidebarSelection.mode(mode))
                    }
                    ForEach(layers(registry), id: \.self) { layer in
                        Label("Layer: \(layer)", systemImage: "square.3.layers.3d")
                            .tag(RegistrySidebarSelection.layer(layer))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 210, ideal: 245, max: 320)
    }

    private func browser(_ registry: KeybindingRegistry) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sidebarTitle)
                        .font(.title2.weight(.semibold))
                    Text("\(filteredBindings(registry).count) bindings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Ownership", selection: $ownership) {
                    Text("All owners").tag("all")
                    Text("Enforced").tag("enforced")
                    Text("Managed profile").tag("managed-profile")
                    Text("Observed").tag("observed")
                }
                .frame(width: 170)
                Toggle("Diagnostics", isOn: $diagnosticsOnly)
                    .toggleStyle(.checkbox)
                Picker("View", selection: $viewMode) {
                    ForEach(RegistryViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            .padding(16)

            Divider()

            if viewMode == .keyboard || sidebarSelection == .freeModifierSpace {
                ModifierSpaceBrowserGrid(
                    registry: registry,
                    matchingBindingIDs: Set(filteredBindings(registry).map(\.id)),
                    freeOnly: sidebarSelection == .freeModifierSpace
                )
            } else {
                bindingList(registry)
            }
        }
        .searchable(
            text: $search,
            placement: .toolbar,
            prompt: "Keys, actions, contexts, tags, sources"
        )
    }

    private func bindingList(_ registry: KeybindingRegistry) -> some View {
        HSplitView {
            List(filteredBindings(registry), selection: $selectedBindingID) { binding in
                RegistryBindingRow(binding: binding)
                    .tag(binding.id)
            }
            .frame(minWidth: 420)

            Group {
                if let selectedBindingID, let binding = registry.binding(withID: selectedBindingID) {
                    RegistryBindingInspector(binding: binding, registry: registry)
                } else {
                    ContentUnavailableView(
                        "Select a Binding",
                        systemImage: "keyboard",
                        description: Text("Source, context, ownership, and diagnostics appear here.")
                    )
                }
            }
            .frame(minWidth: 300, idealWidth: 360)
        }
    }

    private func filteredBindings(_ registry: KeybindingRegistry) -> [RegistryBinding] {
        var query = RegistryQuery(
            search: search,
            ownership: ownership == "all" ? nil : ownership,
            diagnosticsOnly: diagnosticsOnly || sidebarSelection == .diagnostics
        )
        switch sidebarSelection {
        case .provider(let provider):
            query.provider = provider
        case .application(let application):
            query.application = application
        case .mode(let mode):
            query.mode = mode
        case .layer(let layer):
            query.layer = layer
        default:
            break
        }
        let filtered = query.filter(registry)
        if sidebarSelection == .modifierSpace {
            let ids = Set(registry.views.modifierSpace.slots.flatMap(\.bindingIds))
            return filtered.filter { ids.contains($0.id) }
        }
        return filtered
    }

    private var sidebarTitle: String {
        switch sidebarSelection {
        case .all: return "All Bindings"
        case .modifierSpace: return "Modifier + Space"
        case .diagnostics: return "Diagnostics"
        case .freeModifierSpace: return "Free Modifier + Space"
        case .provider(let provider): return provider
        case .application(let application): return application
        case .mode(let mode): return mode
        case .layer(let layer): return "Layer: \(layer)"
        }
    }

    private func applications(_ registry: KeybindingRegistry) -> [String] {
        Array(Set(registry.bindings.compactMap(\.context.application))).sorted()
    }

    private func modes(_ registry: KeybindingRegistry) -> [String] {
        Array(Set(registry.bindings.compactMap(\.context.mode))).sorted()
    }

    private func layers(_ registry: KeybindingRegistry) -> [String] {
        Array(Set(registry.bindings.compactMap(\.context.layer))).sorted()
    }

    private func providerIcon(_ provider: String) -> String {
        switch provider {
        case "aerc": return "envelope"
        case "alttab": return "macwindow.on.rectangle"
        case "kanata": return "keyboard"
        default: return "gearshape"
        }
    }
}


@available(macOS 14, *)
private struct RegistryBindingRow: View {
    let binding: RegistryBinding

    var body: some View {
        HStack(spacing: 12) {
            Text(binding.gesture.display)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .foregroundStyle(Color(hex: "#cba6f7"))
                .frame(width: 120, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(binding.action.label)
                Text(contextLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(binding.ownership)
                .font(.caption2)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
            if !binding.diagnosticIds.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 3)
    }

    private var contextLabel: String {
        [
            binding.provider,
            binding.context.application,
            binding.context.mode,
            binding.context.layer.map { "layer \($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}


@available(macOS 14, *)
private struct RegistryBindingInspector: View {
    let binding: RegistryBinding
    let registry: KeybindingRegistry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(binding.gesture.display)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#cba6f7"))
                    Text(binding.action.label)
                        .font(.title3.weight(.semibold))
                    if let detail = binding.action.detail {
                        Text(detail)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                inspectorSection("Context") {
                    InspectorValue(label: "Stage", value: binding.context.stage)
                    InspectorValue(label: "Application", value: binding.context.application)
                    InspectorValue(label: "Mode", value: binding.context.mode)
                    InspectorValue(label: "Layer", value: binding.context.layer)
                }

                inspectorSection("Ownership") {
                    InspectorValue(label: "Provider", value: binding.provider)
                    InspectorValue(label: "Mode", value: binding.ownership)
                }

                inspectorSection("Source") {
                    InspectorValue(label: "Path", value: binding.source.path)
                    InspectorValue(label: "Target", value: binding.source.target)
                    InspectorValue(
                        label: "Line",
                        value: binding.source.line.map(String.init)
                    )
                }

                if !binding.tags.isEmpty {
                    inspectorSection("Tags") {
                        Text(binding.tags.joined(separator: " · "))
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }

                if !binding.diagnosticIds.isEmpty {
                    inspectorSection("Diagnostics") {
                        ForEach(binding.diagnosticIds, id: \.self) { id in
                            if let diagnostic = registry.diagnostic(withID: id) {
                                Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}


@available(macOS 14, *)
private struct InspectorValue: View {
    let label: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 78, alignment: .leading)
                Text(value)
                    .textSelection(.enabled)
            }
            .font(.caption)
        }
    }
}


@available(macOS 14, *)
private struct ModifierSpaceBrowserGrid: View {
    let registry: KeybindingRegistry
    let matchingBindingIDs: Set<String>
    let freeOnly: Bool

    private var slots: [ModifierSpaceSlot] {
        freeOnly
            ? registry.views.modifierSpace.slots.filter(\.isFree)
            : registry.views.modifierSpace.slots
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 12)],
                spacing: 12
            ) {
                ForEach(slots) { slot in
                    let bindings = slot.bindingIds.compactMap(registry.binding(withID:))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(slot.display)
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(slot.isFree ? .secondary : Color(hex: "#cba6f7"))
                        if slot.isFree {
                            Text("Free")
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(bindings) { binding in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(binding.action.label)
                                    Text(
                                        [binding.provider, binding.context.application, binding.context.mode]
                                            .compactMap { $0 }
                                            .joined(separator: " · ")
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .opacity(
                                    matchingBindingIDs.isEmpty || matchingBindingIDs.contains(binding.id)
                                        ? 1 : 0.28
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .padding(14)
                    .background(.quaternary.opacity(slot.isFree ? 0.35 : 0.7), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
        }
    }
}


@available(macOS 14, *)
private struct RegistryLoadErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Registry Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 8) {
                Text(message)
                Text(KeybindingRegistry.defaultPath())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(40)
    }
}
