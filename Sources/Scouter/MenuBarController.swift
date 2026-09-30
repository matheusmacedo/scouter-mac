import AppKit

@MainActor
final class MenuBarController: NSObject {
    struct Actions {
        var captureArea: () -> Void
        var captureScreen: () -> Void
        var captureScrolling: () -> Void
        var chooseFolder: () -> Void
        var openFolder: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        super.init()
        statusItem.button?.image = Self.menuBarIcon()
        let menu = NSMenu()
        menu.addItem(item("Capture Area or Window", #selector(captureArea), key: "1"))
        menu.addItem(item("Capture Screen", #selector(captureScreen), key: "2"))
        menu.addItem(item("Capture Scrolling", #selector(captureScrolling), key: "3"))
        menu.addItem(.separator())
        menu.addItem(item("Save To…", #selector(chooseFolder)))
        menu.addItem(item("Open Screenshots Folder", #selector(openFolder)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Scouter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    /// The scouter outline from the bundle, tinted by macOS for light and dark menu bars.
    private static func menuBarIcon() -> NSImage? {
        guard let icon = NSImage(named: "MenuBarIcon") else {
            return NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Scouter")
        }
        icon.isTemplate = true
        icon.accessibilityDescription = "Scouter"
        return icon
    }

    /// Key equivalents here are display hints. The real global shortcuts come from HotkeyManager.
    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = [.control, .shift]
        item.target = self
        return item
    }

    @objc private func captureArea() { actions.captureArea() }
    @objc private func captureScreen() { actions.captureScreen() }
    @objc private func captureScrolling() { actions.captureScrolling() }
    @objc private func chooseFolder() { actions.chooseFolder() }
    @objc private func openFolder() { actions.openFolder() }
}
