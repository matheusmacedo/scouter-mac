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

func rowSignatures(_ frame: GrayFrame) -> [RowSignature] {
    (0..<frame.height).map { y in
        let row = frame.row(y)
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in row {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return RowSignature(hash: hash, isUniform: row.allSatisfy { $0 == row.first })
    }
}

/// Finds how far content scrolled up between two same-sized frames.
/// Blank rows on both sides don't count, so empty space can't fake a match.
/// Ties go to the offset nearest `expectedOffset`, which matters for repeating content.
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

    var best: (offset: Int, score: Double)?
    for offset in stride(from: 1, to: body, by: 1) {
        var matches = 0, informative = 0
        for r in top ..< (height - bottom - offset) {
            let old = a[r + offset], new = b[r]
            if old.isUniform && new.isUniform { continue }
            informative += 1
            if old == new { matches += 1 }
        }
        guard informative >= minInformativeRows else { continue }
        let score = Double(matches) / Double(informative)
        guard score >= minMatchRatio else { continue }
        if let current = best {
            let better = score > current.score + 1e-9
            let tieButCloser = abs(score - current.score) <= 1e-9
                && abs(offset - expectedOffset) < abs(current.offset - expectedOffset)
            if better || tieButCloser { best = (offset, score) }
        } else {
            best = (offset, score)
        }
    }
    guard let best else { return .noMatch }
    return .moved(Overlap(offset: best.offset, fixedTop: top, fixedBottom: bottom))
}
