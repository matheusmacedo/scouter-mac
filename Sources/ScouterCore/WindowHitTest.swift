import CoreGraphics
import Foundation

public struct WindowInfo: Equatable, Sendable {
    public let id: UInt32
    public let ownerPID: Int32
    public let layer: Int
    public let alpha: Double
    /// CG global points.
    public let frame: CGRect

    public init(id: UInt32, ownerPID: Int32, layer: Int, alpha: Double, frame: CGRect) {
        self.id = id
        self.ownerPID = ownerPID
        self.layer = layer
        self.alpha = alpha
        self.frame = frame
    }

    /// Reads CGWindowListCopyWindowInfo output. Keeps its front-to-back order.
    public static func parse(_ list: [[String: Any]]) -> [WindowInfo] {
        list.compactMap { entry in
            guard let id = entry[kCGWindowNumber as String] as? Int,
                  let pid = entry[kCGWindowOwnerPID as String] as? Int,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }
            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            return WindowInfo(id: UInt32(id), ownerPID: Int32(pid), layer: layer, alpha: alpha, frame: frame)
        }
    }
}

public enum WindowHitTest {
    /// `windows` must be front to back. Layer 0 is normal app windows. Menu bar, Dock and
    /// overlays sit on higher layers.
    public static func topmost(at point: CGPoint, in windows: [WindowInfo], excludingPID: Int32) -> WindowInfo? {
        windows.first { $0.layer == 0 && $0.alpha > 0 && $0.ownerPID != excludingPID && $0.frame.contains(point) }
    }
}
