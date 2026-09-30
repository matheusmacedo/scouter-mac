import CoreGraphics
import Testing
@testable import SnapbarCore

struct GeometryTests {
    @Test func appKitRectFlipsToCGGlobal() {
        let rect = CGRect(x: 100, y: 700, width: 200, height: 100)
        #expect(Geometry.cgGlobal(fromAppKit: rect, primaryScreenHeight: 1000) == CGRect(x: 100, y: 200, width: 200, height: 100))
    }

    @Test func appKitPointFlipsToCGGlobal() {
        #expect(Geometry.cgGlobal(fromAppKit: CGPoint(x: 50, y: 900), primaryScreenHeight: 1000) == CGPoint(x: 50, y: 100))
    }

    @Test func cgRectFlipsBackToAppKit() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let flipped = Geometry.cgGlobal(fromAppKit: rect, primaryScreenHeight: 900)
        #expect(Geometry.appKit(fromCG: flipped, primaryScreenHeight: 900) == rect)
    }

    @Test func dragInAnyDirectionGivesPositiveRect() {
        let rect = Geometry.rect(from: CGPoint(x: 300, y: 400), to: CGPoint(x: 100, y: 50))
        #expect(rect == CGRect(x: 100, y: 50, width: 200, height: 350))
    }

    @Test func displayLocalSubtractsDisplayOriginAndRoundsOutward() {
        let display = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let rect = CGRect(x: 1500.4, y: 100.6, width: 300.2, height: 200)
        #expect(Geometry.displayLocal(rect, displayFrame: display) == CGRect(x: 60, y: 100, width: 301, height: 201))
    }

    @Test func displayLocalWorksForDisplaysAtNegativeCoordinates() {
        let display = CGRect(x: -1920, y: -1080, width: 1920, height: 1080)
        let rect = CGRect(x: -1000, y: -500, width: 100, height: 100)
        #expect(Geometry.displayLocal(rect, displayFrame: display) == CGRect(x: 920, y: 580, width: 100, height: 100))
    }
}
