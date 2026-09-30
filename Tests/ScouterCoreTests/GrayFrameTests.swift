import Testing
@testable import ScouterCore

struct GrayFrameTests {
    @Test func convertsCGImageWithTopRowFirst() throws {
        let image = makeGrayImage(width: 2, height: 3, pixels: [10, 10, 20, 20, 30, 30])
        let gray = try #require(GrayFrame(cgImage: image))
        #expect(gray.width == 2)
        #expect(gray.height == 3)
        #expect(Array(gray.row(0)) == [10, 10])
        #expect(Array(gray.row(2)) == [30, 30])
    }
}
