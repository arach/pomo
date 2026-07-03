#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Size: Hashable {
    let width: Int
    let height: Int

    var label: String { "\(width)×\(height)" }
}

struct CropRect {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

struct CropRule {
    let filename: String
    let targetSize: Size
    let rectsBySourceSize: [Size: CropRect]
}

let scriptURL = URL(
    fileURLWithPath: CommandLine.arguments[0],
    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
).standardizedFileURL
let cliRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let repoRoot = cliRoot.deletingLastPathComponent().deletingLastPathComponent()
let docsDir = cliRoot.appendingPathComponent("docs")
let landingPublic = repoRoot.appendingPathComponent("landing/public")

let rules: [CropRule] = [
    CropRule(
        filename: "pomo-hud-popover.png",
        targetSize: Size(width: 334, height: 564),
        rectsBySourceSize: [
            // Original capture had broad desktop blur on the left. The 334×624
            // rule is for the first-pass crop that only still needed bottom
            // padding trimmed while preserving the popover arrow.
            Size(width: 420, height: 645): CropRect(x: 78, y: 8, width: 334, height: 564),
            Size(width: 334, height: 624): CropRect(x: 0, y: 0, width: 334, height: 564),
        ]
    ),
    CropRule(
        filename: "pomo-hud-watch.png",
        targetSize: Size(width: 360, height: 276),
        rectsBySourceSize: [
            // Keep a few pixels outside the rounded panel so the border and
            // controls are preserved while trimming dark desktop padding.
            Size(width: 397, height: 357): CropRect(x: 14, y: 39, width: 360, height: 276),
        ]
    ),
    CropRule(
        filename: "pomo-hud-lcd.png",
        targetSize: Size(width: 360, height: 277),
        rectsBySourceSize: [
            Size(width: 491, height: 330): CropRect(x: 62, y: 27, width: 360, height: 277),
        ]
    ),
]

func rel(_ url: URL) -> String {
    let root = repoRoot.path + "/"
    let path = url.path
    if path.hasPrefix(root) {
        return String(path.dropFirst(root.count))
    }
    return path
}

func writePNG(_ image: CGImage, to outputURL: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "crop-hud", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed to create PNG destination"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "crop-hud", code: 2, userInfo: [NSLocalizedDescriptionKey: "failed to write PNG"])
    }
}

func cropIfNeeded(_ path: URL, rule: CropRule) throws {
    guard FileManager.default.fileExists(atPath: path.path) else {
        print("missing \(rel(path)); skipped")
        return
    }

    guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw NSError(domain: "crop-hud", code: 3, userInfo: [NSLocalizedDescriptionKey: "failed to read \(rel(path))"])
    }

    let sourceSize = Size(width: image.width, height: image.height)
    if sourceSize == rule.targetSize {
        print("ok \(rel(path)) already \(sourceSize.label)")
        return
    }

    guard let rect = rule.rectsBySourceSize[sourceSize] else {
        let known = rule.rectsBySourceSize.keys
            .sorted { ($0.width, $0.height) < ($1.width, $1.height) }
            .map(\.label)
            .joined(separator: ", ")
        throw NSError(
            domain: "crop-hud",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "No crop rule for \(rel(path)) at \(sourceSize.label) (known: \(known); target: \(rule.targetSize.label))"]
        )
    }

    let cgRect = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    guard let cropped = image.cropping(to: cgRect) else {
        throw NSError(domain: "crop-hud", code: 5, userInfo: [NSLocalizedDescriptionKey: "failed to crop \(rel(path))"])
    }

    let croppedSize = Size(width: cropped.width, height: cropped.height)
    guard croppedSize == rule.targetSize else {
        throw NSError(
            domain: "crop-hud",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Rule for \(rel(path)) produced \(croppedSize.label), expected \(rule.targetSize.label)"]
        )
    }

    try writePNG(cropped, to: path)
    print("cropped \(rel(path)) \(sourceSize.label) -> \(croppedSize.label)")
}

func syncLandingCopy(filename: String) throws {
    let source = docsDir.appendingPathComponent(filename)
    let target = landingPublic.appendingPathComponent(filename)
    guard FileManager.default.fileExists(atPath: source.path),
          FileManager.default.fileExists(atPath: target.path)
    else {
        return
    }

    let sourceData = try Data(contentsOf: source)
    if let targetData = try? Data(contentsOf: target), sourceData == targetData {
        print("ok \(rel(target)) matches docs copy")
        return
    }

    if FileManager.default.fileExists(atPath: target.path) {
        try FileManager.default.removeItem(at: target)
    }
    try FileManager.default.copyItem(at: source, to: target)
    print("synced \(rel(target)) from apps/cli/docs")
}

do {
    for rule in rules {
        try cropIfNeeded(docsDir.appendingPathComponent(rule.filename), rule: rule)
    }
    for rule in rules {
        try syncLandingCopy(filename: rule.filename)
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
