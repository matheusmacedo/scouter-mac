import CoreGraphics
import Testing
@testable import ScouterCore

struct WindowHitTestTests {
    func window(_ id: UInt32, _ frame: CGRect, pid: Int32 = 100, layer: Int = 0, alpha: Double = 1) -> WindowInfo {
        WindowInfo(id: id, ownerPID: pid, layer: layer, alpha: alpha, frame: frame)
    }

    @Test func picksTheFrontmostWindowUnderThePoint() {
        let front = window(1, CGRect(x: 0, y: 0, width: 500, height: 500))
        let back = window(2, CGRect(x: 0, y: 0, width: 1000, height: 1000))
        #expect(WindowHitTest.topmost(at: CGPoint(x: 100, y: 100), in: [front, back], excludingPID: 1)?.id == 1)
        #expect(WindowHitTest.topmost(at: CGPoint(x: 700, y: 700), in: [front, back], excludingPID: 1)?.id == 2)
    }

    @Test func skipsOurOwnWindows() {
        let ours = window(1, CGRect(x: 0, y: 0, width: 500, height: 500), pid: 42)
        let theirs = window(2, CGRect(x: 0, y: 0, width: 500, height: 500))
        #expect(WindowHitTest.topmost(at: CGPoint(x: 10, y: 10), in: [ours, theirs], excludingPID: 42)?.id == 2)
    }

    @Test func skipsMenuBarDockAndInvisibleWindows() {
        let menuBar = window(1, CGRect(x: 0, y: 0, width: 500, height: 500), layer: 24)
        let invisible = window(2, CGRect(x: 0, y: 0, width: 500, height: 500), alpha: 0)
        let normal = window(3, CGRect(x: 0, y: 0, width: 500, height: 500))
        #expect(WindowHitTest.topmost(at: CGPoint(x: 10, y: 10), in: [menuBar, invisible, normal], excludingPID: 1)?.id == 3)
    }

    @Test func returnsNilOverEmptyDesktop() {
        let w = window(1, CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(WindowHitTest.topmost(at: CGPoint(x: 500, y: 500), in: [w], excludingPID: 1) == nil)
    }

    @Test func parsesCGWindowListEntriesAndSkipsBrokenOnes() {
        let bounds = CGRect(x: 10, y: 20, width: 300, height: 200).dictionaryRepresentation
        let list: [[String: Any]] = [
            [kCGWindowNumber as String: 42, kCGWindowOwnerPID as String: 7, kCGWindowLayer as String: 0,
             kCGWindowAlpha as String: 1.0, kCGWindowBounds as String: bounds],
            [kCGWindowNumber as String: 43, kCGWindowOwnerPID as String: 7],
        ]
        #expect(WindowInfo.parse(list) == [WindowInfo(id: 42, ownerPID: 7, layer: 0, alpha: 1, frame: CGRect(x: 10, y: 20, width: 300, height: 200))])
    }
}
