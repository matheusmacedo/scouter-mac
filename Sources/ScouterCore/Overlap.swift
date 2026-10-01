public struct Overlap: Equatable, Sendable {
    /// Rows the content moved up between the two frames.
    public let offset: Int
    /// Rows at the top and bottom that stayed put, like sticky headers and footers.
    public let fixedTop: Int
    public let fixedBottom: Int

    public init(offset: Int, fixedTop: Int, fixedBottom: Int) {
        self.offset = offset
        self.fixedTop = fixedTop
        self.fixedBottom = fixedBottom
    }
}

public enum OverlapResult: Equatable, Sendable {
    case moved(Overlap)
    case noMovement
    case noMatch
}

let minMatchRatio = 0.9
let minInformativeRows = 8

struct RowSignature: Equatable {
    let hash: UInt64
    let isUniform: Bool
}

/// `columns` limits each signature to a vertical strip of the frame.
func rowSignatures(_ frame: GrayFrame, columns: Range<Int>? = nil) -> [RowSignature] {
    let columns = columns ?? 0 ..< frame.width
    return (0..<frame.height).map { y in
        let row = frame.row(y).dropFirst(columns.lowerBound).prefix(columns.count)
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in row {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return RowSignature(hash: hash, isUniform: row.allSatisfy { $0 == row.first })
    }
}

let stripCount = 8

struct Candidate {
    let offset: Int
    let score: Double
    /// Mismatched rows at the top and bottom of the overlap, taken as see-through sticky bands.
    let lead: Int
    let trail: Int
}

/// Finds how far content scrolled up between two same-sized frames.
/// Blank rows on both sides don't count, so empty space can't fake a match.
/// Ties go to the offset nearest `expectedOffset`, which matters for repeating content.
/// When whole rows don't match, it matches vertical strips on their own, so something
/// animating in place on one side of the frame can't hide that the rest scrolled.
public func findOverlap(previous: GrayFrame, next: GrayFrame, expectedOffset: Int) -> OverlapResult {
    precondition(previous.width == next.width && previous.height == next.height, "frames must be the same size")
    let a = rowSignatures(previous), b = rowSignatures(next)
    let height = a.count

    var top = 0
    while top < height && a[top] == b[top] { top += 1 }
    if top == height { return .noMovement }
    var bottom = 0
    while bottom < height - top && a[height - 1 - bottom] == b[height - 1 - bottom] { bottom += 1 }
    // Blank rows that happen to line up prove nothing. A sticky band must end on a row with content.
    while top > 0 && a[top - 1].isUniform { top -= 1 }
    while bottom > 0 && a[height - bottom].isUniform { bottom -= 1 }
    let body = height - top - bottom

    let rowMatch = candidates(a, b, top: top, bottom: bottom, offsets: 1 ..< body)
    if let best = nearest(rowMatch, to: expectedOffset) {
        return .moved(Overlap(offset: best.offset, fixedTop: top + best.lead, fixedBottom: bottom + best.trail))
    }

    // Each strip votes for the one offset it matches. A strip that matches nowhere is animating,
    // and one that matches in several places is too plain to tell.
    let strips = min(stripCount, previous.width)
    let votes: [Candidate] = (0..<strips).compactMap { s in
        let columns = s * previous.width / strips ..< (s + 1) * previous.width / strips
        let found = candidates(rowSignatures(previous, columns: columns), rowSignatures(next, columns: columns),
                               top: top, bottom: bottom, offsets: 0 ..< body)
        return found.count == 1 ? found[0] : nil
    }
    let tally = Dictionary(grouping: votes, by: \.offset)
    guard let winner = tally.max(by: { lhs, rhs in
        lhs.value.count != rhs.value.count
            ? lhs.value.count < rhs.value.count
            : abs(lhs.key - expectedOffset) > abs(rhs.key - expectedOffset)
    }) else { return .noMatch }
    if winner.key == 0 { return .noMovement }
    // A band only some strips see is still a band, so take the widest.
    let lead = winner.value.map(\.lead).max() ?? 0, trail = winner.value.map(\.trail).max() ?? 0
    return .moved(Overlap(offset: winner.key, fixedTop: top + lead, fixedBottom: bottom + trail))
}

/// Every offset whose overlap matches well enough, for the rows between the fixed bands.
func candidates(_ a: [RowSignature], _ b: [RowSignature], top: Int, bottom: Int, offsets: Range<Int>) -> [Candidate] {
    let height = a.count
    // Sticky bands with see-through backgrounds show different pixels in every frame, so they
    // match neither at the same position nor at the scroll offset. A mismatched run at either edge
    // of the overlap counts as such a band, up to a quarter of the frame.
    let maxChangingBand = height / 4

    var found: [Candidate] = []
    for offset in offsets {
        let rows = top ..< (height - bottom - offset)
        var firstInformative: Int?, lastInformative = 0
        var firstMatch: Int?, lastMatch = 0
        for r in rows {
            let old = a[r + offset], new = b[r]
            if old.isUniform && new.isUniform { continue }
            if firstInformative == nil { firstInformative = r }
            lastInformative = r
            if old == new {
                if firstMatch == nil { firstMatch = r }
                lastMatch = r
            }
        }
        guard let firstInformative, let firstMatch else { continue }
        // Blank rows at the edges aren't a band. Count from the first and last rows with content.
        let lead = firstMatch - firstInformative
        let trail = lastInformative - lastMatch
        // The matched span must cover most of the overlap, or a few coincidental rows could win.
        guard lead <= maxChangingBand, trail <= maxChangingBand,
              (lastMatch - firstMatch + 1) * 2 >= rows.count else { continue }

        var matches = 0, informative = 0
        for r in firstMatch ... lastMatch {
            let old = a[r + offset], new = b[r]
            if old.isUniform && new.isUniform { continue }
            informative += 1
            if old == new { matches += 1 }
        }
        guard informative >= minInformativeRows else { continue }
        let score = Double(matches) / Double(informative)
        guard score >= minMatchRatio else { continue }
        found.append(Candidate(offset: offset, score: score, lead: lead, trail: trail))
    }
    return found
}

/// The best score wins. Ties go to the offset nearest `expectedOffset`.
func nearest(_ found: [Candidate], to expectedOffset: Int) -> Candidate? {
    var best: Candidate?
    for candidate in found {
        guard let current = best else { best = candidate; continue }
        let better = candidate.score > current.score + 1e-9
        let tieButCloser = abs(candidate.score - current.score) <= 1e-9
            && abs(candidate.offset - expectedOffset) < abs(current.offset - expectedOffset)
        if better || tieButCloser { best = candidate }
    }
    return best
}
