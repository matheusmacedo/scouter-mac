import AppKit
import SnapbarCore

enum OutputError: LocalizedError {
    case encodingFailed
    var errorDescription: String? { "Couldn't encode the screenshot as PNG." }
}

struct Output {
    let folder: () -> URL

    @discardableResult
    func deliver(_ capture: Capture) throws -> URL {
        guard let png = ImageEncoding.png(capture.image) else { throw OutputError.encodingFailed }
        let dir = folder()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = CaptureNaming.uniqueURL(in: dir, date: Date())
        try png.write(to: url)
        copyToClipboard(capture, png: png)
        return url
    }

    /// Point size so the image pastes at its on-screen size, PNG plus TIFF so every app accepts it.
    private func copyToClipboard(_ capture: Capture, png: Data) {
        let size = NSSize(width: CGFloat(capture.image.width) / capture.scale,
                          height: CGFloat(capture.image.height) / capture.scale)
        let image = NSImage(cgImage: capture.image, size: size)
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        if let tiff = image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
    }
}
