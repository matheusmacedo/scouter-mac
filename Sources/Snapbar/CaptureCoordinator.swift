import AppKit
import SnapbarCore

@MainActor
final class CaptureCoordinator {
    private let capturer = Capturer()
    private lazy var scrollCapturer = ScrollCapturer(capturer: capturer)
    /// Set before the Task starts so a second press (of either area or scrolling capture) can't slip in before the first await.
    private var captureInProgress = false
    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func captureScreen() {
        guard Permissions.ensureScreenRecording() else { return }
        let point = Geometry.cgGlobal(fromAppKit: NSEvent.mouseLocation, primaryScreenHeight: Screens.primaryHeight)
        Task { await deliver { try await self.capturer.captureDisplay(containing: point) } }
    }

    func captureArea() {
        guard !captureInProgress else { return }
        guard Permissions.ensureScreenRecording() else { return }
        captureInProgress = true
        Task {
            defer { captureInProgress = false }
            switch await SelectionOverlay.select(allowsWindowMode: true) {
            case .area(let rect): await deliver { try await self.capturer.captureRect(rect) }
            case .window(let window): await deliver { try await self.capturer.captureWindow(id: window.id) }
            case .cancelled: return
            }
        }
    }

    func captureScrolling() {
        guard !captureInProgress else { return }
        guard Permissions.ensureScreenRecording(), Permissions.ensureAccessibility() else { return }
        captureInProgress = true
        Task {
            defer { captureInProgress = false }
            guard case .area(let rect) = await SelectionOverlay.select(allowsWindowMode: false) else { return }
            guard rect.height >= 100 else {
                Alerts.info("Select an area at least 100 points tall for a scrolling capture.")
                return
            }
            await deliver { try await self.scrollCapturer.run(rect: rect) }
        }
    }

    private func deliver(_ work: () async throws -> Capture) async {
        do {
            let capture = try await work()
            try await output.deliver(capture)
            NSSound(named: "Tink")?.play()
        } catch {
            Alerts.show(error)
        }
    }
}
