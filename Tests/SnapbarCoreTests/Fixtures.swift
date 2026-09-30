import CoreGraphics
import Foundation
@testable import SnapbarCore

func makeGrayImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage {
    let data = CFDataCreate(nil, pixels, pixels.count)!
    return CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
}

func makeTempDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// Rows of deterministic noise, so every row is unique and none is uniform.
func makePage(width: Int = 16, height: Int, seed: UInt64 = 1) -> [[UInt8]] {
    var state = seed
    return (0..<height).map { _ in
        (0..<width).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return UInt8(truncatingIfNeeded: state >> 56)
        }
    }
}

func frame(_ rows: [[UInt8]]) -> GrayFrame {
    GrayFrame(width: rows[0].count, height: rows.count, pixels: rows.flatMap { $0 })
}

/// A window onto `page` starting at row `top`, with fixed header and footer rows drawn over it.
func viewport(_ page: [[UInt8]], top: Int, height: Int, header: [[UInt8]] = [], footer: [[UInt8]] = []) -> GrayFrame {
    let bodyCount = height - header.count - footer.count
    return frame(header + Array(page[top ..< top + bodyCount]) + footer)
}

func assemble(_ segments: [Segment], frames: [GrayFrame]) -> [[UInt8]] {
    segments.flatMap { segment in segment.rows.map { Array(frames[segment.frameIndex].row($0)) } }
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

/// Each row is filled with one gray value, in sRGB like real captures.
func makeRGBImage(width: Int, rowValues: [UInt8]) -> CGImage {
    let pixels = rowValues.flatMap { v in (0..<width).flatMap { _ in [v, v, v, UInt8(255)] } }
    let data = CFDataCreate(nil, pixels, pixels.count)!
    return CGImage(
        width: width, height: rowValues.count, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: sRGB, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
}

/// Reads back the red channel of the first pixel of every row, top row first.
func redChannelRows(_ image: CGImage) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return (0..<image.height).map { pixels[$0 * image.width * 4] }
}
