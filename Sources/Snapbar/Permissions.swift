import AppKit
import ApplicationServices

@MainActor
enum Permissions {
    static func ensureScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        Alerts.info("Allow Snapbar under System Settings > Privacy & Security > Screen & System Audio Recording, then quit and reopen Snapbar.")
        return false
    }

    static func ensureAccessibility() -> Bool {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        if AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary) { return true }
        Alerts.info("Allow Snapbar under System Settings > Privacy & Security > Accessibility, then quit and reopen Snapbar.")
        return false
    }
}
