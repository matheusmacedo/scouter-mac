// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Scouter",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ScouterCore"),
        .executableTarget(name: "Scouter", dependencies: ["ScouterCore"]),
        .testTarget(name: "ScouterCoreTests", dependencies: ["ScouterCore"]),
    ],
    swiftLanguageModes: [.v5]
)
