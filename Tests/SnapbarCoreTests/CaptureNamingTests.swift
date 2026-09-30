import Foundation
import Testing
@testable import SnapbarCore

struct CaptureNamingTests {
    let utc = TimeZone(identifier: "UTC")!

    func sampleDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 14, minute: 3, second: 22))!
    }

    @Test func fileNameHasDateAndTime() {
        #expect(CaptureNaming.fileName(for: sampleDate(), timeZone: utc) == "Snapbar 2026-09-30 at 14.03.22.png")
    }

    @Test func uniqueURLAddsCounterWhenNameIsTaken() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = CaptureNaming.uniqueURL(in: dir, date: sampleDate(), timeZone: utc)
        #expect(first.lastPathComponent == "Snapbar 2026-09-30 at 14.03.22.png")

        FileManager.default.createFile(atPath: first.path, contents: Data())
        let second = CaptureNaming.uniqueURL(in: dir, date: sampleDate(), timeZone: utc)
        #expect(second.lastPathComponent == "Snapbar 2026-09-30 at 14.03.22 (2).png")

        FileManager.default.createFile(atPath: second.path, contents: Data())
        let third = CaptureNaming.uniqueURL(in: dir, date: sampleDate(), timeZone: utc)
        #expect(third.lastPathComponent == "Snapbar 2026-09-30 at 14.03.22 (3).png")
    }
}
