import CoreGraphics

public enum StitchRenderer {
    /// Draws each segment's rows under the previous one. Keeps the capture's own color space
    /// so colors don't shift.
    public static func render(frames: [Int: CGImage], segments: [Segment]) -> CGImage? {
        let visible = segments.filter { !$0.rows.isEmpty }
        guard let firstIndex = visible.first?.frameIndex, let first = frames[firstIndex] else { return nil }
        let width = first.width
        let height = visible.reduce(0) { $0 + $1.rows.count }
        let space = first.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        var top = 0
        for segment in visible {
            guard let source = frames[segment.frameIndex],
                  let slice = source.cropping(to: CGRect(x: 0, y: segment.rows.lowerBound, width: width, height: segment.rows.count))
            else { return nil }
            // CGImage cropping counts from the top, CGContext drawing counts from the bottom.
            context.draw(slice, in: CGRect(x: 0, y: height - top - segment.rows.count, width: width, height: segment.rows.count))
            top += segment.rows.count
        }
        return context.makeImage()
    }
}
