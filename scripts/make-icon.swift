// Builds Resources/AppIcon.icns, the menu bar template images and a preview from
// Resources/scouter-source.jpg. Run from the repo root: swift scripts/make-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("make-icon: \(message)\n".utf8))
    exit(1)
}

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("can't read \(url.path)") }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("can't write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("can't write \(url.path)") }
}

func context(_ width: Int, _ height: Int) -> CGContext {
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: bitmapInfo) else { fail("can't make a \(width)x\(height) context") }
    ctx.interpolationQuality = .high
    return ctx
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Makes the background transparent by flood-filling from the edges. The source has a fake
/// transparency checkerboard (254 and 237 grey squares) baked in, so any light neutral pixel
/// counts. The drawing's black outline stops the fill, so the scouter's own white body stays.
func cutOut(_ source: CGImage) -> CGImage {
    let width = source.width, height = source.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: space, bitmapInfo: bitmapInfo)!
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    func isBackground(_ i: Int) -> Bool {
        let r = Int(pixels[i * 4]), g = Int(pixels[i * 4 + 1]), b = Int(pixels[i * 4 + 2])
        return min(r, g, b) >= 220 && max(r, g, b) - min(r, g, b) <= 12
    }

    var cleared = [Bool](repeating: false, count: width * height)
    var queue: [Int] = []
    for x in 0 ..< width { queue.append(x); queue.append((height - 1) * width + x) }
    for y in 0 ..< height { queue.append(y * width); queue.append(y * width + width - 1) }
    while let i = queue.popLast() {
        guard !cleared[i], isBackground(i) else { continue }
        cleared[i] = true
        let x = i % width, y = i / width
        if x > 0 { queue.append(i - 1) }
        if x < width - 1 { queue.append(i + 1) }
        if y > 0 { queue.append(i - width) }
        if y < height - 1 { queue.append(i + width) }
    }

    for i in 0 ..< width * height {
        if cleared[i] {
            pixels[i * 4] = 0; pixels[i * 4 + 1] = 0; pixels[i * 4 + 2] = 0; pixels[i * 4 + 3] = 0
            continue
        }
        // Feather light anti-aliased pixels that touch the cleared area so no white fringe is left.
        let x = i % width, y = i / width
        let touchesCleared = (x > 0 && cleared[i - 1]) || (x < width - 1 && cleared[i + 1])
            || (y > 0 && cleared[i - width]) || (y < height - 1 && cleared[i + width])
        let brightness = (Int(pixels[i * 4]) + Int(pixels[i * 4 + 1]) + Int(pixels[i * 4 + 2])) / 3
        if touchesCleared && brightness >= 170 {
            for c in 0 ..< 4 { pixels[i * 4 + c] = UInt8(Int(pixels[i * 4 + c]) / 2) }
        }
    }

    // Crop to the drawing so it centers on the tile.
    var minX = width, minY = height, maxX = 0, maxY = 0
    for y in 0 ..< height {
        for x in 0 ..< width where pixels[(y * width + x) * 4 + 3] > 0 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX > minX, maxY > minY else { fail("cut-out left nothing, is the background white?") }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let full = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: space, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo), provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    return full.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!
}

func appIcon(_ scouter: CGImage) -> CGImage {
    let ctx = context(1024, 1024)
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.4))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x0E0E12))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let background = CGGradient(colorsSpace: space, colors: [color(0x26262E), color(0x0E0E12)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.minY), options: [])

    let drawWidth = tile.width * 0.78
    let drawHeight = drawWidth * CGFloat(scouter.height) / CGFloat(scouter.width)
    let art = CGRect(x: tile.midX - drawWidth / 2, y: tile.midY - drawHeight / 2, width: drawWidth, height: drawHeight)
    // The red lens sits on the left of the drawing, a bit below the middle.
    let lens = CGPoint(x: art.minX + art.width * 0.25, y: art.maxY - art.height * 0.6)
    let glow = CGGradient(colorsSpace: space, colors: [color(0xE8302A, 0.35), color(0xE8302A, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: lens, startRadius: 0, endCenter: lens, endRadius: tile.width * 0.45, options: [])

    ctx.draw(scouter, in: art)
    ctx.restoreGState()
    return ctx.makeImage()!
}

/// Alpha channel of `image` drawn fitted and centered into a size×size square.
func alphaMask(_ image: CGImage, size: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let ctx = CGContext(data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: size * 4, space: space, bitmapInfo: bitmapInfo)!
        ctx.interpolationQuality = .high
        let scale = min(CGFloat(size) / CGFloat(image.width), CGFloat(size) / CGFloat(image.height))
        let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
        ctx.draw(image, in: CGRect(x: (CGFloat(size) - w) / 2, y: (CGFloat(size) - h) / 2, width: w, height: h))
    }
    return (0 ..< size * size).map { pixels[$0 * 4 + 3] }
}

/// Keeps only the red lens pixels of the cut-out drawing.
func lensOnly(_ scouter: CGImage) -> CGImage {
    let width = scouter.width, height = scouter.height
    let ctx = context(width, height)
    ctx.draw(scouter, in: CGRect(x: 0, y: 0, width: width, height: height))
    let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
    for i in 0 ..< width * height {
        let r = Int(data[i * 4]), g = Int(data[i * 4 + 1]), b = Int(data[i * 4 + 2])
        if !(r > 150 && r > g + 60 && r > b + 60) { for c in 0 ..< 4 { data[i * 4 + c] = 0 } }
    }
    return ctx.makeImage()!
}

/// Outline of the scouter with a solid lens, black on transparent. macOS tints template
/// images for light and dark menu bars. A plain silhouette reads as a blob at this size.
func menuIcon(_ scouter: CGImage, size: Int) -> CGImage {
    let shape = alphaMask(scouter, size: size)
    let lens = alphaMask(lensOnly(scouter), size: size)
    let stroke = max(1, size / 18)
    var inner = shape
    for _ in 0 ..< stroke {
        inner = (0 ..< size * size).map { i in
            let x = i % size, y = i / size
            var m = inner[i]
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx, ny = y + dy
                m = (nx < 0 || ny < 0 || nx >= size || ny >= size) ? 0 : min(m, inner[ny * size + nx])
            }
            return m
        }
    }
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    for i in 0 ..< size * size {
        let outline = Int(shape[i]) - Int(inner[i])
        pixels[i * 4 + 3] = UInt8(min(255, max(outline, Int(lens[i]))))
    }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                   space: space, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo), provider: provider,
                   decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
}

func scaled(_ image: CGImage, to size: Int) -> CGImage {
    let ctx = context(size, size)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

let scouter = cutOut(loadImage(resources.appendingPathComponent("scouter-source.jpg")))
let icon = appIcon(scouter)
writePNG(icon, to: resources.appendingPathComponent("icon-preview.png"))
writePNG(menuIcon(scouter, size: 18), to: resources.appendingPathComponent("MenuBarIcon.png"))
writePNG(menuIcon(scouter, size: 36), to: resources.appendingPathComponent("MenuBarIcon@2x.png"))

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(scaled(icon, to: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(scaled(icon, to: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fail("iconutil failed") }
print("Wrote Resources/AppIcon.icns, MenuBarIcon.png, MenuBarIcon@2x.png, icon-preview.png")
