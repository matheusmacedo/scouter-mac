// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Snapbar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SnapbarCore"),
        .testTarget(name: "SnapbarCoreTests", dependencies: ["SnapbarCore"]),
    ],
    swiftLanguageModes: [.v5]
)
