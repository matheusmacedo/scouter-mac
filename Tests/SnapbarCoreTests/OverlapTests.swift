import Testing
@testable import SnapbarCore

struct OverlapTests {
    let page = makePage(height: 300)

    @Test func findsHowFarContentMoved() {
        let result = findOverlap(previous: viewport(page, top: 0, height: 100),
                                 next: viewport(page, top: 37, height: 100),
                                 expectedOffset: 40)
        #expect(result == .moved(Overlap(offset: 37, fixedTop: 0, fixedBottom: 0)))
    }

    @Test func identicalFramesMeanNoMovement() {
        let still = viewport(page, top: 20, height: 100)
        #expect(findOverlap(previous: still, next: still, expectedOffset: 40) == .noMovement)
    }

    @Test func unrelatedFramesMeanNoMatch() {
        let other = makePage(height: 100, seed: 99)
        #expect(findOverlap(previous: viewport(page, top: 0, height: 100), next: frame(other), expectedOffset: 40) == .noMatch)
    }

    @Test func detectsStickyHeaderAndFooter() {
        let header = makePage(height: 10, seed: 7)
        let footer = makePage(height: 6, seed: 9)
        let result = findOverlap(previous: viewport(page, top: 0, height: 100, header: header, footer: footer),
                                 next: viewport(page, top: 25, height: 100, header: header, footer: footer),
                                 expectedOffset: 30)
        #expect(result == .moved(Overlap(offset: 25, fixedTop: 10, fixedBottom: 6)))
    }

    @Test func toleratesAFewChangedRowsLikeABlinkingCaret() {
        var nextRows = Array(page[37 ..< 137])
        for r in 50...52 { nextRows[r] = Array(repeating: 0, count: 16) }
        let result = findOverlap(previous: viewport(page, top: 0, height: 100), next: frame(nextRows), expectedOffset: 40)
        #expect(result == .moved(Overlap(offset: 37, fixedTop: 0, fixedBottom: 0)))
    }

    @Test func repeatingContentPicksOffsetNearestTheRequestedScroll() {
        let pattern = makePage(height: 20, seed: 3)
        let repeating = Array((0..<10).map { _ in pattern }.joined())
        // Offsets 10, 30, 50, 70 and 90 all match perfectly. 30 is closest to 32.
        let result = findOverlap(previous: frame(Array(repeating[0 ..< 100])),
                                 next: frame(Array(repeating[30 ..< 130])),
                                 expectedOffset: 32)
        #expect(result == .moved(Overlap(offset: 30, fixedTop: 0, fixedBottom: 0)))
    }

    @Test func mostlyBlankPageStillMatchesOnTheRowsWithContent() {
        let white = Array(repeating: UInt8(255), count: 16)
        let sparse = makePage(height: 400, seed: 5).enumerated().map { $0.offset % 15 == 0 ? $0.element : white }
        let result = findOverlap(previous: viewport(sparse, top: 0, height: 200),
                                 next: viewport(sparse, top: 45, height: 200),
                                 expectedOffset: 50)
        #expect(result == .moved(Overlap(offset: 45, fixedTop: 0, fixedBottom: 0)))
    }

    @Test func translucentStickyHeaderThatChangesEveryFrameStillMatches() {
        // A blurred header shows different pixels in every frame, so it's neither fixed nor moving content.
        let result = findOverlap(previous: viewport(page, top: 0, height: 100, header: makePage(height: 10, seed: 21)),
                                 next: viewport(page, top: 60, height: 100, header: makePage(height: 10, seed: 22)),
                                 expectedOffset: 60)
        #expect(result == .moved(Overlap(offset: 60, fixedTop: 10, fixedBottom: 0)))
    }

    @Test func changingBandAtTheBottomCountsAsFixedFooter() {
        let result = findOverlap(previous: viewport(page, top: 0, height: 100, footer: makePage(height: 8, seed: 31)),
                                 next: viewport(page, top: 60, height: 100, footer: makePage(height: 8, seed: 32)),
                                 expectedOffset: 60)
        #expect(result == .moved(Overlap(offset: 60, fixedTop: 0, fixedBottom: 8)))
    }
}
