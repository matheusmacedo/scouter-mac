import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var coordinator: CaptureCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let coordinator = CaptureCoordinator(output: Output(folder: { desktop }))
        self.coordinator = coordinator
        menuBar = MenuBarController(actions: .init(
            captureArea: { coordinator.captureArea() },
            captureScreen: { coordinator.captureScreen() },
            captureScrolling: { coordinator.captureScrolling() },
            openFolder: { NSWorkspace.shared.open(desktop) }
        ))
    }
}
