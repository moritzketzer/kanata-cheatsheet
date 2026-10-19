import AppKit
import CryptoKit
import Foundation
import SwiftUI


private enum VisualRendererError: Error, CustomStringConvertible {
    case usage
    case missingKeyboardGeometry
    case noKeyboardLayers
    case renderFailed(String)
    case contactSheetFailed(String)
    case hashMismatch(String)
    case missingSymbol(position: String, token: String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: render-contact-sheets --registry PATH --output DIRECTORY [--width-percent 1...100]"
        case .missingKeyboardGeometry:
            return "Registry has no keyboard geometry profiles"
        case .noKeyboardLayers:
            return "Registry has no keyboard layers"
        case .renderFailed(let layer):
            return "Could not render keyboard layer: \(layer)"
        case .contactSheetFailed(let profile):
            return "Could not render contact sheet: \(profile)"
        case .hashMismatch(let path):
            return "Written image hash did not verify: \(path)"
        case .missingSymbol(let position, let token):
            return "Missing SF Symbol for Yabai \(position): \(token)"
        }
    }
}


private struct Invocation {
    let registryURL: URL
    let outputURL: URL
    let widthPercent: Int
}


private struct RenderedImage: Encodable {
    let path: String
    let profileId: String
    let layerId: String?
    let width: Int
    let height: Int
    let sha256: String
}


private struct ReviewManifest: Encodable {
    let registryPath: String
    let profileIds: [String]
    let layerIds: [String]
    let images: [RenderedImage]
}


private struct RenderedLayer {
    let layerId: String
    let data: Data
    let width: Int
    let height: Int
}


/// Fixed contact-sheet geometry; every measure derives from the cell count.
private struct ContactSheetLayout {
    let cellCount: Int
    let columns = 2
    let outerPadding = 24
    let gutter = 24
    let titleHeight = 72
    let labelHeight = 44
    let thumbnailWidth = 1500
    let thumbnailHeight = 950

    var rows: Int { (cellCount + columns - 1) / columns }
    var cellWidth: Int { thumbnailWidth + outerPadding * 2 }
    var cellHeight: Int { thumbnailHeight + labelHeight + outerPadding * 2 }
    var canvasWidth: Int { cellWidth * columns + gutter * (columns - 1) }
    var canvasHeight: Int { titleHeight + cellHeight * rows + gutter * (rows - 1) }
}


@main
private struct VisualRenderer {
    @MainActor
    static func main() throws {
        let invocation = try parseInvocation()
        let registry = try KeybindingRegistry.load(
            from: invocation.registryURL.path
        )
        guard let keyboardLayers = registry.views.keyboardLayers,
              let geometry = keyboardLayers.geometry
        else { throw VisualRendererError.missingKeyboardGeometry }

        let layerIds = keyboardLayers.layers.keys.sorted()
        guard !layerIds.isEmpty else {
            throw VisualRendererError.noKeyboardLayers
        }
        let profiles = geometry.effectiveProfiles
        guard !profiles.isEmpty else {
            throw VisualRendererError.missingKeyboardGeometry
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: invocation.outputURL,
            withIntermediateDirectories: true
        )
        _ = NSApplication.shared.setActivationPolicy(.prohibited)
        try validateYabaiSymbols(keyboardLayers.layers["yabai"])

        let examples = try pomodoroExamples()
        let display = Config.Display(width_percent: invocation.widthPercent)
        var imageRecords: [RenderedImage] = []
        for profile in profiles {
            try fileManager.createDirectory(
                at: invocation.outputURL.appendingPathComponent(
                    profile.id,
                    isDirectory: true
                ),
                withIntermediateDirectories: true
            )

            let baseLayers = try renderBaseLayers(
                layerIds: layerIds,
                profile: profile,
                registry: registry,
                display: display,
                pomodoroStatus: examples.first { $0.name == "paused" }?.status,
                outputURL: invocation.outputURL
            )
            var rendered = baseLayers
            if keyboardLayers.layers["pomodoro"] != nil {
                rendered += try renderPomodoroExamples(
                    examples,
                    profile: profile,
                    registry: registry,
                    display: display,
                    outputURL: invocation.outputURL
                )
            }
            rendered += try renderYabaiModifierStates(
                profile: profile,
                registry: registry,
                display: display,
                outputURL: invocation.outputURL
            )
            if profile.kind == "defy" {
                rendered.append(try renderInputPathPreview(
                    profile: profile,
                    registry: registry,
                    display: display,
                    outputURL: invocation.outputURL
                ))
            }
            imageRecords += rendered.map { record($0, profileId: profile.id) }
            imageRecords.append(try renderContactSheetImage(
                profile: profile,
                layers: baseLayers,
                outputURL: invocation.outputURL
            ))
        }

        try writeManifest(
            ReviewManifest(
                registryPath: invocation.registryURL.path,
                profileIds: profiles.map(\.id),
                layerIds: layerIds,
                images: imageRecords
            ),
            to: invocation.outputURL
        )
    }

    private static func parseInvocation() throws -> Invocation {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard [4, 6].contains(arguments.count),
              arguments[0] == "--registry",
              arguments[2] == "--output"
        else { throw VisualRendererError.usage }

        let widthPercent: Int
        if arguments.count == 6 {
            guard arguments[4] == "--width-percent",
                  let value = Int(arguments[5]), (1...100).contains(value)
            else { throw VisualRendererError.usage }
            widthPercent = value
        } else {
            widthPercent = 75
        }
        return Invocation(
            registryURL: URL(fileURLWithPath: arguments[1]).standardizedFileURL,
            outputURL: URL(fileURLWithPath: arguments[3]).standardizedFileURL,
            widthPercent: widthPercent
        )
    }

    /// Every Pomodoro header state worth reviewing, including the unavailable
    /// one the reader sees when no snapshot exists.
    private static func pomodoroExamples() throws
        -> [(name: String, status: PomodoroStatus?)]
    {
        let decoded: [(name: String, status: PomodoroStatus?)] = try [
            ("ready", "idle", "work", "general", 1500, 0),
            ("running", "running", "work", "dissertation", 222, 720),
            ("paused", "paused", "work", "dissertation", 222, 720),
            ("break", "running", "break", "dissertation", 180, 720),
            ("expired", "expired", "work", "dissertation", -60, 1500),
            ("target-reached", "paused", "work", "dissertation", 222, 2461),
        ].map { name, state, mode, context, remaining, progress in
            let json = """
            {"schema_version":1,"observed_at":1000,"state":"\(state)","mode":"\(mode)","context":"\(context)","remaining_seconds":\(remaining),"date":"2026-09-08","dissertation_seconds":\(progress)}
            """
            return (name, try JSONDecoder().decode(PomodoroStatus.self, from: Data(json.utf8)))
        }
        return decoded + [("unavailable", nil)]
    }

    private static func validateYabaiSymbols(
        _ layer: RegistryKeyboardLayer?
    ) throws {
        guard let layer else { return }
        for (position, cell) in layer.cells.sorted(by: { $0.key < $1.key }) {
            let visuals = [cell.presentation?.primary]
                + (cell.presentation?.modifierVariants?.map(\.primary) ?? [])
            for visual in visuals.compactMap({ $0 }) where visual.kind == "sf-symbol" {
                guard NSImage(
                    systemSymbolName: visual.token,
                    accessibilityDescription: nil
                ) != nil else {
                    throw VisualRendererError.missingSymbol(
                        position: position,
                        token: visual.token
                    )
                }
            }
        }
    }

    @MainActor
    private static func renderBaseLayers(
        layerIds: [String],
        profile: RegistryKeyboardGeometryProfile,
        registry: KeybindingRegistry,
        display: Config.Display,
        pomodoroStatus: PomodoroStatus?,
        outputURL: URL
    ) throws -> [RenderedLayer] {
        try layerIds.map { layerId in
            try writeImage(
                view: KeyboardView(
                    layerName: layerId,
                    legacyLayer: nil,
                    display: display,
                    registry: registry,
                    showFreeModifierSpace: false,
                    geometryProfileId: profile.id,
                    yabaiQualifier: layerId == "yabai" ? "Preview" : nil,
                    pomodoroStatus: layerId == "pomodoro" ? pomodoroStatus : nil
                ),
                layerId: layerId,
                profileId: profile.id,
                outputURL: outputURL
            )
        }
    }

    @MainActor
    private static func renderPomodoroExamples(
        _ examples: [(name: String, status: PomodoroStatus?)],
        profile: RegistryKeyboardGeometryProfile,
        registry: KeybindingRegistry,
        display: Config.Display,
        outputURL: URL
    ) throws -> [RenderedLayer] {
        try examples.map { example in
            try writeImage(
                view: KeyboardView(
                    layerName: "pomodoro",
                    legacyLayer: nil,
                    display: display,
                    registry: registry,
                    geometryProfileId: profile.id,
                    pomodoroStatus: example.status
                ),
                layerId: "pomodoro-\(example.name)",
                profileId: profile.id,
                outputURL: outputURL
            )
        }
    }

    private static let yabaiStates: [(name: String, modifiers: Set<YabaiModifier>)] = [
        ("base", []),
        ("option", [.option]),
        ("shift", [.shift]),
        ("command", [.command]),
        ("control", [.control]),
        ("command-shift", [.command, .shift]),
    ]

    @MainActor
    private static func renderYabaiModifierStates(
        profile: RegistryKeyboardGeometryProfile,
        registry: KeybindingRegistry,
        display: Config.Display,
        outputURL: URL
    ) throws -> [RenderedLayer] {
        try yabaiStates.map { state in
            try writeImage(
                view: KeyboardView(
                    layerName: "yabai",
                    legacyLayer: nil,
                    display: display,
                    registry: registry,
                    showFreeModifierSpace: false,
                    geometryProfileId: profile.id,
                    activeModifiers: state.modifiers,
                    yabaiQualifier: "Preview"
                ),
                layerId: "yabai-\(state.name)",
                profileId: profile.id,
                outputURL: outputURL
            )
        }
    }

    @MainActor
    private static func renderInputPathPreview(
        profile: RegistryKeyboardGeometryProfile,
        registry: KeybindingRegistry,
        display: Config.Display,
        outputURL: URL
    ) throws -> RenderedLayer {
        try writeImage(
            view: KeyboardView(
                layerName: "mine",
                legacyLayer: nil,
                display: display,
                registry: registry,
                showFreeModifierSpace: false,
                geometryProfileId: profile.id,
                showInputPath: true
            ),
            layerId: "mine-input-path",
            profileId: profile.id,
            outputURL: outputURL
        )
    }

    @MainActor
    private static func renderContactSheetImage(
        profile: RegistryKeyboardGeometryProfile,
        layers: [RenderedLayer],
        outputURL: URL
    ) throws -> RenderedImage {
        let sheetData = try contactSheet(
            profileLabel: profile.label,
            layers: layers
        )
        let sheetPath = "\(profile.id)-contact-sheet.png"
        try writeVerified(
            sheetData,
            to: outputURL.appendingPathComponent(sheetPath)
        )
        let sheetDimensions = try imageDimensions(sheetData)
        return RenderedImage(
            path: sheetPath,
            profileId: profile.id,
            layerId: nil,
            width: sheetDimensions.width,
            height: sheetDimensions.height,
            sha256: sha256(sheetData)
        )
    }

    private static func writeManifest(
        _ manifest: ReviewManifest,
        to outputURL: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(
            to: outputURL.appendingPathComponent("manifest.json"),
            options: .atomic
        )
    }

    /// Renders one layer view and writes its verified PNG to the path the
    /// manifest will report for it.
    @MainActor
    private static func writeImage(
        view: KeyboardView,
        layerId: String,
        profileId: String,
        outputURL: URL
    ) throws -> RenderedLayer {
        let rendered = try render(view: view, layerId: layerId)
        try writeVerified(
            rendered.data,
            to: outputURL.appendingPathComponent(
                imagePath(profileId: profileId, layerId: layerId)
            )
        )
        return rendered
    }

    private static func record(
        _ rendered: RenderedLayer,
        profileId: String
    ) -> RenderedImage {
        RenderedImage(
            path: imagePath(profileId: profileId, layerId: rendered.layerId),
            profileId: profileId,
            layerId: rendered.layerId,
            width: rendered.width,
            height: rendered.height,
            sha256: sha256(rendered.data)
        )
    }

    private static func imagePath(profileId: String, layerId: String) -> String {
        "\(profileId)/\(layerId).png"
    }

    @MainActor
    private static func render(
        view: KeyboardView,
        layerId: String
    ) throws -> RenderedLayer {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 1600, height: 1)
        host.invalidateIntrinsicContentSize()
        host.layoutSubtreeIfNeeded()
        let fittingSize = host.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else {
            throw VisualRendererError.renderFailed(layerId)
        }
        host.frame = NSRect(origin: .zero, size: fittingSize)
        host.layoutSubtreeIfNeeded()
        guard let representation = host.bitmapImageRepForCachingDisplay(
            in: host.bounds
        ) else {
            throw VisualRendererError.renderFailed(layerId)
        }
        host.cacheDisplay(in: host.bounds, to: representation)
        guard let data = representation.representation(
            using: .png,
            properties: [:]
        ) else {
            throw VisualRendererError.renderFailed(layerId)
        }
        return RenderedLayer(
            layerId: layerId,
            data: data,
            width: representation.pixelsWide,
            height: representation.pixelsHigh
        )
    }

    @MainActor
    private static func contactSheet(
        profileLabel: String,
        layers: [RenderedLayer]
    ) throws -> Data {
        let images = try layers.map { layer -> (RenderedLayer, NSImage) in
            guard let image = NSImage(data: layer.data) else {
                throw VisualRendererError.contactSheetFailed(profileLabel)
            }
            return (layer, image)
        }
        let layout = ContactSheetLayout(cellCount: layers.count)
        let canvas = try makeCanvas(
            width: layout.canvasWidth,
            height: layout.canvasHeight,
            profileLabel: profileLabel
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = canvas.context
        NSColor(calibratedRed: 0.075, green: 0.075, blue: 0.11, alpha: 1).setFill()
        NSRect(
            x: 0,
            y: 0,
            width: layout.canvasWidth,
            height: layout.canvasHeight
        ).fill()

        let title = NSAttributedString(
            string: profileLabel.uppercased(),
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 36, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 0.80, green: 0.65, blue: 0.97, alpha: 1),
            ]
        )
        title.draw(at: NSPoint(
            x: layout.outerPadding,
            y: layout.canvasHeight - 52
        ))

        for (index, pair) in images.enumerated() {
            drawCell(index: index, layer: pair.0, image: pair.1, layout: layout)
        }

        NSGraphicsContext.restoreGraphicsState()
        guard let data = canvas.representation.representation(
            using: .png,
            properties: [:]
        ) else {
            throw VisualRendererError.contactSheetFailed(profileLabel)
        }
        return data
    }

    private static func makeCanvas(
        width: Int,
        height: Int,
        profileLabel: String
    ) throws -> (representation: NSBitmapImageRep, context: NSGraphicsContext) {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: representation)
        else {
            throw VisualRendererError.contactSheetFailed(profileLabel)
        }
        return (representation, context)
    }

    @MainActor
    private static func drawCell(
        index: Int,
        layer: RenderedLayer,
        image: NSImage,
        layout: ContactSheetLayout
    ) {
        let column = index % layout.columns
        let row = index / layout.columns
        let cellX = column * (layout.cellWidth + layout.gutter)
        let cellTop = layout.canvasHeight - layout.titleHeight
            - row * (layout.cellHeight + layout.gutter)
        let label = NSAttributedString(
            string: layer.layerId.uppercased(),
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: NSColor(calibratedWhite: 0.70, alpha: 1),
            ]
        )
        label.draw(at: NSPoint(
            x: cellX + layout.outerPadding,
            y: cellTop - layout.labelHeight
        ))
        let scale = min(
            1,
            min(
                CGFloat(layout.thumbnailWidth) / CGFloat(layer.width),
                CGFloat(layout.thumbnailHeight) / CGFloat(layer.height)
            )
        )
        let imageWidth = Int((CGFloat(layer.width) * scale).rounded())
        let imageHeight = Int((CGFloat(layer.height) * scale).rounded())
        let imageX = cellX + layout.outerPadding
            + (layout.thumbnailWidth - imageWidth) / 2
        let imageY = cellTop - layout.labelHeight - layout.outerPadding - imageHeight
        image.draw(
            in: NSRect(
                x: imageX,
                y: imageY,
                width: imageWidth,
                height: imageHeight
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    private static func imageDimensions(_ data: Data) throws -> (width: Int, height: Int) {
        guard let representation = NSBitmapImageRep(data: data) else {
            throw VisualRendererError.contactSheetFailed("unknown")
        }
        return (representation.pixelsWide, representation.pixelsHigh)
    }

    private static func writeVerified(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        let written = try Data(contentsOf: url)
        guard sha256(written) == sha256(data) else {
            throw VisualRendererError.hashMismatch(url.path)
        }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
