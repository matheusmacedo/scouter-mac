import AppKit

enum Screens {
    /// The primary screen is always first and anchors both coordinate systems.
    @MainActor static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
}
