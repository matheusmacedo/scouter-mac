import AppKit
import SnapbarCore

@MainActor
final class CaptureCoordinator {
    private let capturer = Capturer()
    private lazy var scrollCapturer = ScrollCapturer(capturer: capturer)
    /// Set before the Task starts so a second press can't slip in before the first await.
    private var scrollInProgress = false
    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func captureScreen() {
        guard Permissions.ensureScreenRecording() else { return }
        let point = Geometry.cgGlobal(fromAppKit: NSEvent.mouseLocation, primaryScreenHeight: Screens.primaryHeight)
        Task { await deliver { try await self.capturer.captureDisplay(containing: point) } }
    }

    func captureScrolling() {
        guard !scrollInProgress else { return }
        guard Permissions.ensureScreenRecording(), Permissions.ensureAccessibility() else { return }
        // Temporary: middle 60% of the primary screen. Task 8 replaces this with a selection.
        let screen = NSScreen.screens[0].frame
        let rect = CGRect(x: screen.width * 0.2, y: screen.height * 0.2, width: screen.width * 0.6, height: screen.height * 0.6)
        scrollInProgress = true
        Task {
            defer { scrollInProgress = false }
            await deliver { try await self.scrollCapturer.run(rect: rect) }
        }
    }

    private func deliver(_ work: () async throws -> Capture) async {
        do {
            let capture = try await work()
            try output.deliver(capture)
            NSSound(named: "Tink")?.play()
        } catch {
            Alerts.show(error)
        }
    }
}
