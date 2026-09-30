// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Snapbar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.0.0"),
    ],
    targets: [
        .target(name: "SnapbarCore"),
        .testTarget(name: "SnapbarCoreTests", dependencies: ["SnapbarCore", .product(name: "Testing", package: "swift-testing")]),
    ],
    swiftLanguageModes: [.v5]
)
