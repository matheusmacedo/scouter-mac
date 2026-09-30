import AppKit
import ScouterCore

enum OutputError: LocalizedError {
    case encodingFailed
    var errorDescription: String? { "Couldn't encode the screenshot as PNG." }
}

struct Output {
    let folder: () -> URL

    @discardableResult
    func deliver(_ capture: Capture) async throws -> URL {
        let image = capture.image, scale = capture.scale
        guard let png = await (Task.detached { ImageEncoding.png(image, scale: scale) }).value else {
            throw OutputError.encodingFailed
        }
        let dir = folder()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = CaptureNaming.uniqueURL(in: dir, date: Date())
        try png.write(to: url)
        copyToClipboard(png: png)
        return url
    }

    /// PNG only; every app that accepts a screenshot paste reads PNG.
    private func copyToClipboard(png: Data) {
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
    }
}
