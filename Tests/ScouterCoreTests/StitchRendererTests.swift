import CoreGraphics
import Testing
@testable import SnapbarCore

struct StitchRendererTests {
    @Test func stacksSegmentsTopToBottom() throws {
        let frames: [Int: CGImage] = [
            0: makeRGBImage(width: 4, rowValues: [10, 11, 12, 13]),
            2: makeRGBImage(width: 4, rowValues: [20, 21, 22, 23]),
        ]
        let segments = [Segment(frameIndex: 0, rows: 0 ..< 3), Segment(frameIndex: 2, rows: 1 ..< 4)]
        let image = try #require(StitchRenderer.render(frames: frames, segments: segments))
        #expect(image.width == 4)
        #expect(redChannelRows(image) == [10, 11, 12, 21, 22, 23])
    }

    @Test func skipsEmptySegments() throws {
        let frames: [Int: CGImage] = [0: makeRGBImage(width: 2, rowValues: [1, 2]), 1: makeRGBImage(width: 2, rowValues: [3, 4])]
        let segments = [Segment(frameIndex: 0, rows: 0 ..< 2), Segment(frameIndex: 1, rows: 2 ..< 2)]
        let image = try #require(StitchRenderer.render(frames: frames, segments: segments))
        #expect(redChannelRows(image) == [1, 2])
    }

    @Test func returnsNilWhenAFrameIsMissing() {
        let segments = [Segment(frameIndex: 5, rows: 0 ..< 2)]
        #expect(StitchRenderer.render(frames: [0: makeRGBImage(width: 2, rowValues: [1, 2])], segments: segments) == nil)
    }
}
