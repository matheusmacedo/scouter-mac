import CoreGraphics
import ImageIO
import Testing
@testable import SnapbarCore

struct ImageEncodingTests {
    @Test func pngRoundTripKeepsSize() throws {
        let image = makeGrayImage(width: 3, height: 2, pixels: [0, 50, 100, 150, 200, 250])
        let data = try #require(ImageEncoding.png(image))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 3)
        #expect(decoded.height == 2)
    }
}
