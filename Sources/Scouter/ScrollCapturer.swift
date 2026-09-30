import AppKit
import ScouterCore

enum ScrollCaptureError: LocalizedError {
    case unreadableFrame
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unreadableFrame: "Couldn't read the captured frame."
        case .renderFailed: "Couldn't stitch the scrolling capture."
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
            let shot = try await capturer.captureRect(rect)
            guard let gray = GrayFrame(cgImage: shot.image) else { throw ScrollCaptureError.unreadableFrame }
            // A display change mid-capture would otherwise hit findOverlap's precondition and crash.
            guard gray.width == firstGray.width, gray.height == firstGray.height else { break loop }
            index += 1
            let step = session.add(gray)
            // Only frames the stitched image uses stay in memory.
            if session.segments.last?.frameIndex == index { frames[index] = shot.image }
            if case .finished = step { break loop }
        }

        let segments = session.segments
        let rendered = await (Task.detached { StitchRenderer.render(frames: frames, segments: segments) }).value
        guard let image = rendered else { throw ScrollCaptureError.renderFailed }
        return Capture(image: image, scale: first.scale)
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
