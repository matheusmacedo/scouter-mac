import Foundation

public final class SettingsStore {
    private static let saveFolderKey = "saveFolder"
    private let defaults: UserDefaults
    private let defaultFolder: URL
    private let fileManager: FileManager

    public init(defaults: UserDefaults, defaultFolder: URL, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.defaultFolder = defaultFolder
        self.fileManager = fileManager
    }

    /// Falls back to the default when the saved folder was deleted or its drive is unplugged.
    public var saveFolder: URL {
        get {
            guard let path = defaults.string(forKey: Self.saveFolderKey) else { return defaultFolder }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return defaultFolder
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set { defaults.set(newValue.path, forKey: Self.saveFolderKey) }
    }
}
