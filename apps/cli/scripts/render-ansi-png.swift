#!/usr/bin/env swift
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Cell: Decodable {
    let ch: String
    let fg: [Int]
    let bg: [Int]
}

struct Spec: Decodable {
    let width: Int
    let height: Int
    let rows: [[Cell]]
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: render-ansi-png.swift <spec.json> <out.png>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
let data = try Data(contentsOf: inputURL)
let spec = try JSONDecoder().decode(Spec.self, from: data)

let fontSize: CGFloat = 13
let font = CTFontCreateWithName("Menlo-Regular" as CFString, fontSize, nil)
let boldFont = CTFontCreateWithName("Menlo-Bold" as CFString, fontSize, nil)
var adv: CGSize = .zero
CTFontGetAdvancesForGlyphs(font, .horizontal, [CTFontGetGlyphWithName(font, "M" as CFString)], &adv, 1)
let cellW = max(8, ceil(adv.width) + 2)
let cellH = max(16, ceil(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)))
let padX: CGFloat = 16
let padY: CGFloat = 16
let imgW = Int(padX * 2 + cellW * CGFloat(spec.width))
let imgH = Int(padY * 2 + cellH * CGFloat(spec.height))

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: imgW,
    height: imgH,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("failed to create context\n", stderr)
    exit(1)
}

func cgColor(_ rgb: [Int], alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat(rgb.count > 0 ? rgb[0] : 200) / 255
    let g = CGFloat(rgb.count > 1 ? rgb[1] : 200) / 255
    let b = CGFloat(rgb.count > 2 ? rgb[2] : 200) / 255
    return CGColor(red: r, green: g, blue: b, alpha: alpha)
}

ctx.setFillColor(cgColor([10, 10, 12]))
ctx.fill(CGRect(x: 0, y: 0, width: imgW, height: imgH))

func drawText(_ text: String, at point: CGPoint, useFont: CTFont, color: CGColor) {
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: useFont,
        kCTForegroundColorAttributeName: color,
    ]
    let line = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let framesetter = CTFramesetterCreateWithAttributedString(line)
    let path = CGPath(rect: CGRect(x: point.x, y: point.y, width: cellW, height: cellH), transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: CFAttributedStringGetLength(line)), path, nil)
    CTFrameDraw(frame, ctx)
}

for (y, row) in spec.rows.enumerated() {
    for (x, cell) in row.enumerated() {
        let bgRect = CGRect(
            x: padX + CGFloat(x) * cellW,
            y: CGFloat(imgH) - padY - CGFloat(y + 1) * cellH,
            width: cellW,
            height: cellH
        )
        ctx.setFillColor(cgColor(cell.bg))
        ctx.fill(bgRect)
        let text = cell.ch.isEmpty ? " " : cell.ch
        let useBold = text.count == 1 && text == text.uppercased() && text != text.lowercased()
        let drawPoint = CGPoint(x: bgRect.minX + 1, y: bgRect.minY + 2)
        drawText(text, at: drawPoint, useFont: useBold ? boldFont : font, color: cgColor(cell.fg))
    }
}

guard let image = ctx.makeImage() else {
    fputs("failed to make image\n", stderr)
    exit(1)
}

guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs("failed to create destination\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    fputs("failed to write png\n", stderr)
    exit(1)
}