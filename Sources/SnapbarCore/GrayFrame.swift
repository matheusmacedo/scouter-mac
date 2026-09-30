import CoreGraphics

/// 8-bit grayscale pixels, row-major, top row first.
public struct GrayFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "pixel count must be width * height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init?(cgImage: CGImage) {
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.init(width: width, height: height, pixels: pixels)
    }

    public func row(_ y: Int) -> ArraySlice<UInt8> {
        pixels[(y * width) ..< ((y + 1) * width)]
    }
}
