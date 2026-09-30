public struct Segment: Equatable, Sendable {
    public let frameIndex: Int
    public var rows: Range<Int>

    public init(frameIndex: Int, rows: Range<Int>) {
        self.frameIndex = frameIndex
        self.rows = rows
    }
}

public enum StopReason: Equatable, Sendable {
    case endReached
    case lostTrack
    case heightLimit
}

public enum ScrollStep: Equatable, Sendable {
    case moved
    case still
    case finished(StopReason)
}

/// Feeds frames one at a time and keeps the list of row ranges that make up the stitched image.
/// Each frame's segment runs to the bottom of the frame, footer included. When the next frame
/// arrives, the footer gets trimmed off, so only the last frame keeps it.
public struct ScrollSession {
    public private(set) var segments: [Segment]
    public private(set) var hasMoved = false
    /// Sign for the scroll wheel delta. Negative scrolls down with standard settings.
    public private(set) var scrollSign: Int32 = -1
    public var height: Int { segments.reduce(0) { $0 + $1.rows.count } }

    private let expectedOffset: Int
    private let maxHeight: Int
    private var previous: GrayFrame
    private var nextIndex = 1
    private var stillCount = 0
    private var flipped = false

    public init(first: GrayFrame, expectedOffset: Int, maxHeight: Int) {
        segments = [Segment(frameIndex: 0, rows: 0 ..< first.height)]
        previous = first
        self.expectedOffset = expectedOffset
        self.maxHeight = maxHeight
    }

    public mutating func add(_ frame: GrayFrame) -> ScrollStep {
        let index = nextIndex
        nextIndex += 1

        switch findOverlap(previous: previous, next: frame, expectedOffset: expectedOffset) {
        case .noMatch:
            return .finished(.lostTrack)

        case .noMovement:
            if !hasMoved && !flipped {
                flipped = true
                scrollSign = -scrollSign
                return .still
            }
            stillCount += 1
            return stillCount >= 2 ? .finished(.endReached) : .still

        case .moved(let overlap):
            let bodyEnd = frame.height - overlap.fixedBottom
            let last = segments.count - 1
            let lower = segments[last].rows.lowerBound
            // A sticky band that grew past what the last frame added can't be stitched cleanly.
            guard bodyEnd >= lower else { return .finished(.lostTrack) }
            stillCount = 0
            hasMoved = true
            segments[last].rows = lower ..< bodyEnd
            segments.append(Segment(frameIndex: index, rows: (bodyEnd - overlap.offset) ..< frame.height))
            previous = frame
            return height >= maxHeight ? .finished(.heightLimit) : .moved
        }
    }
}
