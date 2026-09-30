import AppKit
import ScouterCore

enum WindowList {
    static func current() -> [WindowInfo] {
        let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        return WindowInfo.parse(raw as? [[String: Any]] ?? [])
    }
}
