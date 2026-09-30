import AppKit
import Carbon.HIToolbox
import SnapbarCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var coordinator: CaptureCoordinator?
    private let hotkeys = HotkeyManager()
    private let settings = SettingsStore(
        defaults: .standard,
        defaultFolder: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = self.settings
        let coordinator = CaptureCoordinator(output: Output(folder: { settings.saveFolder }))
        self.coordinator = coordinator

        menuBar = MenuBarController(actions: .init(
            captureArea: { coordinator.captureArea() },
            captureScreen: { coordinator.captureScreen() },
            captureScrolling: { coordinator.captureScrolling() },
            chooseFolder: { [weak self] in self?.chooseFolder() },
            openFolder: { NSWorkspace.shared.open(settings.saveFolder) }
        ))

        let modifiers = controlKey | shiftKey
        hotkeys.register(keyCode: kVK_ANSI_1, modifiers: modifiers) { coordinator.captureArea() }
        hotkeys.register(keyCode: kVK_ANSI_2, modifiers: modifiers) { coordinator.captureScreen() }
        hotkeys.register(keyCode: kVK_ANSI_3, modifiers: modifiers) { coordinator.captureScrolling() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.saveFolder
        panel.prompt = "Save Here"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolder = url
        }
    }
}
