import AppKit
import SnapbarCore

@MainActor
enum ScrollHUD {
    /// Sits near the bottom of the screen being captured. Captures exclude our own windows,
    /// so it never ends up in the image.
    static func show(for cgRect: CGRect) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 36),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        let label = NSTextField(labelWithString: "Scrolling… press Esc to stop")
        label.textColor = .white
        label.frame = NSRect(x: 12, y: 9, width: 236, height: 18)
        panel.contentView?.addSubview(label)

        let appKitRect = Geometry.appKit(fromCG: cgRect, primaryScreenHeight: Screens.primaryHeight)
        let screen = NSScreen.screens.first { $0.frame.intersects(appKitRect) } ?? NSScreen.screens[0]
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - 130, y: screen.frame.minY + 40))
        panel.orderFrontRegardless()
        return panel
    }
}
