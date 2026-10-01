import AppKit
import ScouterCore

enum ScrollCaptureError: LocalizedError {
    case unreadableFrame
    case renderFailed
    case didNotScroll

    var errorDescription: String? {
        switch self {
        case .unreadableFrame: "Couldn't read the captured frame."
        case .renderFailed: "Couldn't stitch the scrolling capture."
        case .didNotScroll: "The page didn't scroll. Select an area over a scrollable part of the page. If you just allowed Accessibility, quit and reopen Scouter."
        }
    }
}

@MainActor
final class ScrollCapturer {
    private let capturer: Capturer
    private var cancelled = false
    private var monitors: [Any] = []

    init(capturer: Capturer) {
        self.capturer = capturer
    }

    /// `rect` is in CG global points.
    func run(rect: CGRect) async throws -> Capture {
        cancelled = false
        installEscMonitor()
        let hud = ScrollHUD.show(for: rect)
        defer {
            removeEscMonitor()
            hud.close()
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        _ = CGWarpMouseCursorPosition(center)
        let stepPoints = max(40, Int(rect.height * 0.6))

        let first = try await capturer.captureRect(rect)
        guard let firstGray = GrayFrame(cgImage: first.image) else { throw ScrollCaptureError.unreadableFrame }
        var frames: [Int: CGImage] = [0: first.image]
        var session = ScrollSession(first: firstGray, expectedOffset: Int(CGFloat(stepPoints) * first.scale), maxHeight: 20_000)
        var index = 0

        loop: while !cancelled {
            postScroll(delta: Int32(stepPoints) * session.scrollSign, at: center)
            try await Task.sleep(for: .milliseconds(300))
            guard let (shot, gray) = try await captureSettled(rect, size: firstGray) else { break loop }
            index += 1
            let step = session.add(gray)
            // Only frames the stitched image uses stay in memory.
            if session.segments.last?.frameIndex == index { frames[index] = shot.image }
            if case .finished = step { break loop }
        }

        // Esc before any movement still saves the first frame, since the user chose to stop.
        guard session.hasMoved || cancelled else { throw ScrollCaptureError.didNotScroll }

        let segments = session.segments
        let rendered = await (Task.detached { StitchRenderer.render(frames: frames, segments: segments) }).value
        guard let image = rendered else { throw ScrollCaptureError.renderFailed }
        return Capture(image: image, scale: first.scale)
    }

    /// Smooth scrolling and fade-in effects keep the page changing after the scroll lands, so this
    /// captures until two frames in a row show nothing moved, giving up after ten tries.
    /// Returns nil when the frame size changes, since a display change mid-capture would otherwise
    /// hit findOverlap's precondition and crash.
    private func captureSettled(_ rect: CGRect, size reference: GrayFrame) async throws -> (Capture, GrayFrame)? {
        var latest: (Capture, GrayFrame)?
        for _ in 0 ..< 10 {
            let shot = try await capturer.captureRect(rect)
            guard let gray = GrayFrame(cgImage: shot.image) else { throw ScrollCaptureError.unreadableFrame }
            guard gray.width == reference.width, gray.height == reference.height else { return nil }
            if let (_, previous) = latest, findOverlap(previous: previous, next: gray, expectedOffset: 0) == .noMovement {
                return (shot, gray)
            }
            latest = (shot, gray)
            try await Task.sleep(for: .milliseconds(150))
        }
        return latest
    }

    private func postScroll(delta: Int32, at point: CGPoint) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                  wheel1: delta, wheel2: 0, wheel3: 0) else { return }
        event.location = point
        event.post(tap: .cghidEventTap)
    }

    /// The global monitor needs Accessibility, which scrolling capture already requires.
    private func installEscMonitor() {
        let onKey: (NSEvent) -> Void = { [weak self] event in
            if event.keyCode == 53 { self?.cancelled = true }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: onKey) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { onKey($0); return $0 }) { monitors.append(local) }
    }

    private func removeEscMonitor() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}
