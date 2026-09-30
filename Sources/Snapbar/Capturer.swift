import AppKit
import ScreenCaptureKit
import SnapbarCore

struct Capture {
    let image: CGImage
    let scale: CGFloat
}

enum CaptureError: LocalizedError {
    case noDisplay
    case noWindow

    var errorDescription: String? {
        switch self {
        case .noDisplay: "Couldn't find a display to capture."
        case .noWindow: "That window is gone."
        }
    }
}

struct Capturer {
    func captureDisplay(containing point: CGPoint) async throws -> Capture {
        let content = try await shareableContent()
        guard let display = content.displays.first(where: { $0.frame.contains(point) }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }
        return try await capture(display: display, sourceRect: nil, content: content)
    }

    /// `rect` is in CG global points. The display under the rect's center is used, and anything
    /// outside that display gets clipped.
    func captureRect(_ rect: CGRect) async throws -> Capture {
        let content = try await shareableContent()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        guard let display = content.displays.first(where: { $0.frame.contains(center) }) else {
            throw CaptureError.noDisplay
        }
        let local = Geometry.displayLocal(rect, displayFrame: display.frame)
            .intersection(CGRect(origin: .zero, size: display.frame.size))
        return try await capture(display: display, sourceRect: local, content: content)
    }

    func captureWindow(id: CGWindowID) async throws -> Capture {
        let content = try await shareableContent()
        guard let window = content.windows.first(where: { $0.windowID == id }) else { throw CaptureError.noWindow }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        // Shadows would make the image bigger than the configured size and get squashed.
        config.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return Capture(image: image, scale: scale)
    }

    private func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    /// Our own overlay and HUD windows never show up in captures.
    private func ownWindows(_ content: SCShareableContent) -> [SCWindow] {
        let pid = ProcessInfo.processInfo.processIdentifier
        return content.windows.filter { $0.owningApplication?.processID == pid }
    }

    private func capture(display: SCDisplay, sourceRect: CGRect?, content: SCShareableContent) async throws -> Capture {
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows(content))
        let scale = CGFloat(filter.pointPixelScale)
        let size = sourceRect?.size ?? display.frame.size
        let config = SCStreamConfiguration()
        if let sourceRect { config.sourceRect = sourceRect }
        config.width = Int(size.width * scale)
        config.height = Int(size.height * scale)
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return Capture(image: image, scale: scale)
    }
}
