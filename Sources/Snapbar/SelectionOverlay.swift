import AppKit
import SnapbarCore

enum SelectionResult {
    /// CG global points.
    case area(CGRect)
    case cancelled
}

/// One borderless window per screen. The windows share this object's state and each draws its own part.
@MainActor
final class SelectionOverlay {
    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<SelectionResult, Never>?
    fileprivate var dragStart: NSPoint?
    fileprivate var dragCurrent: NSPoint?

    static func select() async -> SelectionResult {
        let overlay = SelectionOverlay()
        return await withCheckedContinuation { continuation in
            overlay.continuation = continuation
            overlay.show()
        }
    }

    /// AppKit global coordinates.
    fileprivate var selection: NSRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return Geometry.rect(from: start, to: current)
    }

    private func show() {
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.setFrame(screen.frame, display: false)
            window.contentView = SelectionView(overlay: self)
            windows.append(window)
        }
        windows.forEach { $0.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        NSCursor.crosshair.push()
    }

    fileprivate func redraw() {
        windows.forEach { $0.contentView?.needsDisplay = true }
    }

    fileprivate func mouseDown(at point: NSPoint) {
        dragStart = point
        dragCurrent = point
        redraw()
    }

    fileprivate func mouseDragged(to point: NSPoint) {
        dragCurrent = point
        redraw()
    }

    fileprivate func mouseUp(at point: NSPoint) {
        dragCurrent = point
        // A click without a real drag resets instead of capturing a sliver.
        guard let rect = selection, rect.width >= 4, rect.height >= 4 else {
            dragStart = nil
            dragCurrent = nil
            redraw()
            return
        }
        finish(.area(Geometry.cgGlobal(fromAppKit: rect, primaryScreenHeight: Screens.primaryHeight)))
    }

    fileprivate func keyDown(_ event: NSEvent) {
        if event.keyCode == 53 { finish(.cancelled) }
    }

    private func finish(_ result: SelectionResult) {
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    private let overlay: SelectionOverlay

    init(overlay: SelectionOverlay) {
        self.overlay = overlay
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func globalPoint(_ event: NSEvent) -> NSPoint {
        window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
    }

    override func mouseDown(with event: NSEvent) { overlay.mouseDown(at: globalPoint(event)) }
    override func mouseDragged(with event: NSEvent) { overlay.mouseDragged(to: globalPoint(event)) }
    override func mouseUp(with event: NSEvent) { overlay.mouseUp(at: globalPoint(event)) }
    override func keyDown(with event: NSEvent) { overlay.keyDown(event) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        guard let global = overlay.selection, let window else { return }
        let local = global.offsetBy(dx: -window.frame.minX, dy: -window.frame.minY)
        NSColor.clear.setFill()
        local.fill(using: .copy)
        NSColor.white.setStroke()
        NSBezierPath(rect: local.insetBy(dx: -0.5, dy: -0.5)).stroke()
        let label = "\(Int(global.width)) × \(Int(global.height))" as NSString
        label.draw(at: NSPoint(x: local.minX, y: local.maxY + 4), withAttributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
        ])
    }
}
