import AppKit
import CryptoKit
import Foundation
import SwiftUI


private enum VisualRendererError: Error, CustomStringConvertible {
    case usage
    case missingKeyboardGeometry
    case unexpectedLayerCount(Int)
    case renderFailed(String)
    case contactSheetFailed(String)
    case hashMismatch(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: render-contact-sheets --registry PATH --output DIRECTORY"
        case .missingKeyboardGeometry:
            return "Registry has no keyboard geometry profiles"
        case .unexpectedLayerCount(let count):
            return "Expected ten keyboard layers, found \(count)"
        case .renderFailed(let layer):
            return "Could not render keyboard layer: \(layer)"
        case .contactSheetFailed(let profile):
            return "Could not render contact sheet: \(profile)"
        case .hashMismatch(let path):
            return "Written image hash did not verify: \(path)"
        }
    }
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


@main
private struct VisualRenderer {
    @MainActor
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 4,
              arguments[0] == "--registry",
              arguments[2] == "--output"
        else { throw VisualRendererError.usage }

        let registryURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
        let outputURL = URL(fileURLWithPath: arguments[3]).standardizedFileURL
        let registry = try KeybindingRegistry.load(from: registryURL.path)
        guard let keyboardLayers = registry.views.keyboardLayers,
              let geometry = keyboardLayers.geometry
        else { throw VisualRendererError.missingKeyboardGeometry }

        let layerIds = keyboardLayers.layers.keys.sorted()
        guard layerIds.count == 10 else {
            throw VisualRendererError.unexpectedLayerCount(layerIds.count)
        }
        let profiles = geometry.effectiveProfiles
        guard !profiles.isEmpty else {
            throw VisualRendererError.missingKeyboardGeometry
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true
        )
        _ = NSApplication.shared.setActivationPolicy(.prohibited)

        let display = Config.Display(width_percent: 75)
        var imageRecords: [RenderedImage] = []
        for profile in profiles {
            let profileURL = outputURL.appendingPathComponent(
                profile.id,
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: profileURL,
                withIntermediateDirectories: true
            )
            var renderedLayers: [RenderedLayer] = []
            for layerId in layerIds {
                let view = KeyboardView(
                    layerName: layerId,
                    legacyLayer: nil,
                    display: display,
                    registry: registry,
                    showFreeModifierSpace: false,
                    geometryProfileId: profile.id
                )
                let rendered = try render(view: view, layerId: layerId)
                let relativePath = "\(profile.id)/\(layerId).png"
                let imageURL = outputURL.appendingPathComponent(relativePath)
                try writeVerified(rendered.data, to: imageURL)
                renderedLayers.append(rendered)
                imageRecords.append(RenderedImage(
                    path: relativePath,
                    profileId: profile.id,
                    layerId: layerId,
                    width: rendered.width,
                    height: rendered.height,
                    sha256: sha256(rendered.data)
                ))
            }

            let sheetData = try contactSheet(
                profileLabel: profile.label,
                layers: renderedLayers
            )
            let sheetPath = "\(profile.id)-contact-sheet.png"
            let sheetURL = outputURL.appendingPathComponent(sheetPath)
            try writeVerified(sheetData, to: sheetURL)
            let sheetDimensions = try imageDimensions(sheetData)
            imageRecords.append(RenderedImage(
                path: sheetPath,
                profileId: profile.id,
                layerId: nil,
                width: sheetDimensions.width,
                height: sheetDimensions.height,
                sha256: sha256(sheetData)
            ))
        }

        let manifest = ReviewManifest(
            registryPath: registryURL.path,
            profileIds: profiles.map(\.id),
            layerIds: layerIds,
            images: imageRecords
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(
            to: outputURL.appendingPathComponent("manifest.json"),
            options: .atomic
        )
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
        let columns = 2
        let rows = 5
        let outerPadding = 24
        let gutter = 24
        let titleHeight = 72
        let labelHeight = 44
        let thumbnailWidth = 1500
        let thumbnailHeight = 950
        let cellWidth = thumbnailWidth + outerPadding * 2
        let cellHeight = thumbnailHeight + labelHeight + outerPadding * 2
        let canvasWidth = cellWidth * columns + gutter * (columns - 1)
        let canvasHeight = titleHeight + cellHeight * rows + gutter * (rows - 1)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: canvasWidth,
            pixelsHigh: canvasHeight,
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

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(calibratedRed: 0.075, green: 0.075, blue: 0.11, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()

        let title = NSAttributedString(
            string: profileLabel.uppercased(),
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 36, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 0.80, green: 0.65, blue: 0.97, alpha: 1),
            ]
        )
        title.draw(at: NSPoint(x: outerPadding, y: canvasHeight - 52))

        for (index, pair) in images.enumerated() {
            let column = index % columns
            let row = index / columns
            let cellX = column * (cellWidth + gutter)
            let cellTop = canvasHeight - titleHeight - row * (cellHeight + gutter)
            let label = NSAttributedString(
                string: pair.0.layerId.uppercased(),
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 28, weight: .semibold),
                    .foregroundColor: NSColor(calibratedWhite: 0.70, alpha: 1),
                ]
            )
            label.draw(at: NSPoint(
                x: cellX + outerPadding,
                y: cellTop - labelHeight
            ))
            let scale = min(
                1,
                min(
                    CGFloat(thumbnailWidth) / CGFloat(pair.0.width),
                    CGFloat(thumbnailHeight) / CGFloat(pair.0.height)
                )
            )
            let imageWidth = Int((CGFloat(pair.0.width) * scale).rounded())
            let imageHeight = Int((CGFloat(pair.0.height) * scale).rounded())
            let imageX = cellX + outerPadding
                + (thumbnailWidth - imageWidth) / 2
            let imageY = cellTop - labelHeight - outerPadding - imageHeight
            pair.1.draw(
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

        NSGraphicsContext.restoreGraphicsState()
        guard let data = representation.representation(
            using: .png,
            properties: [:]
        ) else {
            throw VisualRendererError.contactSheetFailed(profileLabel)
        }
        return data
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
