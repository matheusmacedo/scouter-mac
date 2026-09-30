import AppKit
import SnapbarCore

@MainActor
final class CaptureCoordinator {
    private let capturer = Capturer()
    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func captureScreen() {
        guard Permissions.ensureScreenRecording() else { return }
        let point = Geometry.cgGlobal(fromAppKit: NSEvent.mouseLocation, primaryScreenHeight: Screens.primaryHeight)
        Task { await deliver { try await self.capturer.captureDisplay(containing: point) } }
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
