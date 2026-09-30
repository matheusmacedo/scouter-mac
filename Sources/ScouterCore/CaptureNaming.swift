import Foundation

public enum CaptureNaming {
    public static func fileName(for date: Date, timeZone: TimeZone = .current, suffix: String = "") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Snapbar \(formatter.string(from: date))\(suffix).png"
    }

    public static func uniqueURL(
        in folder: URL, date: Date, timeZone: TimeZone = .current, fileManager: FileManager = .default
    ) -> URL {
        var url = folder.appendingPathComponent(fileName(for: date, timeZone: timeZone))
        var counter = 2
        while fileManager.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent(fileName(for: date, timeZone: timeZone, suffix: " (\(counter))"))
            counter += 1
        }
        return url
    }
}
