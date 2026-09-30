// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Snapbar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SnapbarCore"),
        .executableTarget(name: "Snapbar", dependencies: ["SnapbarCore"]),
        .testTarget(name: "SnapbarCoreTests", dependencies: ["SnapbarCore"]),
    ],
    swiftLanguageModes: [.v5]
)
