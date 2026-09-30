import CoreGraphics
import ImageIO
import Testing
@testable import ScouterCore

struct ImageEncodingTests {
    @Test func pngRoundTripKeepsSize() throws {
        let image = makeGrayImage(width: 3, height: 2, pixels: [0, 50, 100, 150, 200, 250])
        let data = try #require(ImageEncoding.png(image))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 3)
        #expect(decoded.height == 2)
    }

    @Test func pngRecordsRetinaDPI() throws {
        let image = makeGrayImage(width: 2, height: 2, pixels: [0, 50, 100, 150])
        let data = try #require(ImageEncoding.png(image, scale: 2))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyDPIWidth] as? Double == 144)
        #expect(properties[kCGImagePropertyDPIHeight] as? Double == 144)
    }
}
