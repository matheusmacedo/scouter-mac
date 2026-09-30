import Foundation
import Testing
@testable import SnapbarCore

struct SettingsStoreTests {
    let fallback = URL(fileURLWithPath: "/tmp/snapbar-default", isDirectory: true)

    func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "snapbar-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    @Test func usesDefaultFolderWhenNothingIsSaved() {
        withDefaults { defaults in
            #expect(SettingsStore(defaults: defaults, defaultFolder: fallback).saveFolder == fallback)
        }
    }

    @Test func remembersTheChosenFolderAcrossInstances() throws {
        try withDefaults { defaults in
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            SettingsStore(defaults: defaults, defaultFolder: fallback).saveFolder = dir
            #expect(SettingsStore(defaults: defaults, defaultFolder: fallback).saveFolder.path == dir.path)
        }
    }

    @Test func fallsBackWhenTheChosenFolderIsGone() throws {
        try withDefaults { defaults in
            let dir = try makeTempDirectory()
            let store = SettingsStore(defaults: defaults, defaultFolder: fallback)
            store.saveFolder = dir
            try FileManager.default.removeItem(at: dir)
            #expect(store.saveFolder == fallback)
        }
    }
}
