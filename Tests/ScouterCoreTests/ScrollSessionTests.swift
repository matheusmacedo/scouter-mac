import Testing
@testable import SnapbarCore

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

    @Test func stopsWhenTrackingIsLost() {
        var session = ScrollSession(first: viewport(page, top: 0, height: 100), expectedOffset: 50, maxHeight: 10_000)
        #expect(session.add(frame(makePage(height: 100, seed: 42))) == .finished(.lostTrack))
        #expect(session.height == 100)
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
