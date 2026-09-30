import CoreGraphics

/// AppKit global coordinates have their origin at the bottom left of the primary screen, y up.
/// CG global coordinates (CGEvent, CGWindowList, ScreenCaptureKit) have it at the top left, y down.
public enum Geometry {
    public static func cgGlobal(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func cgGlobal(fromAppKit point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// The flip is its own inverse.
    public static func appKit(fromCG rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        cgGlobal(fromAppKit: rect, primaryScreenHeight: primaryScreenHeight)
    }

    public static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// ScreenCaptureKit's sourceRect is in points relative to the display's top left corner.
    public static func displayLocal(_ rect: CGRect, displayFrame: CGRect) -> CGRect {
        rect.offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY).integral
    }
}
