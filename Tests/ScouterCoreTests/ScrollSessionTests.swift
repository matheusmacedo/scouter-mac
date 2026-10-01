import Testing
@testable import ScouterCore

struct ScrollSessionTests {
    let page = makePage(height: 400)

    @Test func stitchesFramesBackIntoThePage() {
        let frames = [0, 60, 120].map { viewport(page, top: $0, height: 100) }
        var session = ScrollSession(first: frames[0], expectedOffset: 60, maxHeight: 10_000)
        #expect(session.add(frames[1]) == .moved)
        #expect(session.add(frames[2]) == .moved)
        #expect(assemble(session.segments, frames: frames) == Array(page[0 ..< 220]))
        #expect(session.height == 220)
    }

    @Test func keepsStickyHeaderOnceAndFooterOnlyAtTheEnd() {
        let header = makePage(height: 10, seed: 7)
        let footer = makePage(height: 6, seed: 9)
        let frames = [0, 30, 60].map { viewport(page, top: $0, height: 100, header: header, footer: footer) }
        var session = ScrollSession(first: frames[0], expectedOffset: 30, maxHeight: 10_000)
        _ = session.add(frames[1])
        _ = session.add(frames[2])
        #expect(assemble(session.segments, frames: frames) == header + Array(page[0 ..< 144]) + footer)
    }

    @Test func stopsAfterTwoStillFramesOnceItHasMoved() {
        let frames = [0, 50, 50, 50].map { viewport(page, top: $0, height: 100) }
        var session = ScrollSession(first: frames[0], expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(frames[1]) == .moved)
        #expect(session.add(frames[2]) == .still)
        #expect(session.add(frames[3]) == .finished(.endReached))
        #expect(assemble(session.segments, frames: frames) == Array(page[0 ..< 150]))
    }

    @Test func flipsScrollDirectionOnceWhenTheFirstScrollDoesNothing() {
        let first = viewport(page, top: 0, height: 100)
        var session = ScrollSession(first: first, expectedOffset: 50, maxHeight: 10_000)
        #expect(session.scrollSign == -1)
        #expect(session.add(first) == .still)
        #expect(session.scrollSign == 1)
        #expect(session.add(viewport(page, top: 50, height: 100)) == .moved)
    }

    @Test func givesUpWhenNeitherDirectionMoves() {
        let first = viewport(page, top: 0, height: 100)
        var session = ScrollSession(first: first, expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(first) == .still)
        #expect(session.add(first) == .still)
        #expect(session.add(first) == .finished(.endReached))
        #expect(session.segments == [Segment(frameIndex: 0, rows: 0 ..< 100)])
    }

    @Test func stopsWhenTrackingIsLostBeforeAnyMove() {
        var session = ScrollSession(first: viewport(page, top: 0, height: 100), expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(frame(makePage(height: 100, seed: 42))) == .finished(.lostTrack))
        #expect(session.height == 100)
    }

    @Test func trustsTheRequestedScrollWhenAMovedFrameCantBeMatched() {
        // Frame 2 sits at row 100, but a scroll-linked animation redrew all of it.
        let frames = [
            viewport(page, top: 0, height: 100),
            viewport(page, top: 50, height: 100),
            frame(makePage(height: 100, seed: 42)),
            viewport(page, top: 150, height: 100),
        ]
        var session = ScrollSession(first: frames[0], expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(frames[1]) == .moved)
        #expect(session.add(frames[2]) == .moved)
        #expect(session.add(frames[3]) == .moved)
        let stitched = assemble(session.segments, frames: frames)
        #expect(stitched.count == 250)
        #expect(Array(stitched[0 ..< 150]) == Array(page[0 ..< 150]))
        #expect(Array(stitched[200 ..< 250]) == Array(page[200 ..< 250]))
    }

    @Test func givesUpAfterThreeUnmatchedFramesInARow() {
        var session = ScrollSession(first: viewport(page, top: 0, height: 100), expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(viewport(page, top: 50, height: 100)) == .moved)
        for seed in UInt64(42)...44 { #expect(session.add(frame(makePage(height: 100, seed: seed))) == .moved) }
        #expect(session.add(frame(makePage(height: 100, seed: 45))) == .finished(.lostTrack))
    }

    /// The first frame with its right half redrawn, like floating cards on a page that didn't move.
    func animatedStill(seed: UInt64 = 42) -> GrayFrame {
        animate(viewport(page, top: 0, height: 100), columns: 8 ..< 16, seed: seed)
    }

    @Test func flipsDirectionWhenAStillPageHasAnimation() {
        var session = ScrollSession(first: viewport(page, top: 0, height: 100), expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(animatedStill()) == .still)
        #expect(session.scrollSign == 1)
        #expect(session.add(viewport(page, top: 50, height: 100)) == .moved)
    }

    @Test func givesUpWhenAnAnimatedPageNeverMoves() {
        var session = ScrollSession(first: viewport(page, top: 0, height: 100), expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(animatedStill(seed: 42)) == .still)
        #expect(session.add(animatedStill(seed: 43)) == .still)
        #expect(session.add(animatedStill(seed: 44)) == .finished(.endReached))
        #expect(session.segments == [Segment(frameIndex: 0, rows: 0 ..< 100)])
    }

    @Test func footerThatGrowsMidScrollIsStitchedOnce() {
        let smallFooter = makePage(height: 6, seed: 9)
        let bigFooter = makePage(height: 34, seed: 11) + smallFooter
        let frames = [
            viewport(page, top: 0, height: 100, footer: smallFooter),
            viewport(page, top: 30, height: 100, footer: bigFooter),
            viewport(page, top: 60, height: 100, footer: bigFooter),
        ]
        var session = ScrollSession(first: frames[0], expectedOffset: 30, maxHeight: 10_000)
        #expect(session.add(frames[1]) == .moved)
        #expect(session.add(frames[2]) == .moved)
        #expect(assemble(session.segments, frames: frames) == Array(page[0 ..< 120]) + bigFooter)
    }

    @Test func stopsAtTheHeightLimit() {
        let frames = [0, 50, 100].map { viewport(page, top: $0, height: 100) }
        var session = ScrollSession(first: frames[0], expectedOffset: 50, maxHeight: 180)
        #expect(session.add(frames[1]) == .moved)
        #expect(session.add(frames[2]) == .finished(.heightLimit))
    }
}
