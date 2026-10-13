// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Awake",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "AwakeCore", path: "src/AwakeCore"),
        .executableTarget(name: "Awake", dependencies: ["AwakeCore"], path: "src/Awake"),
        .testTarget(name: "AwakeCoreTests", dependencies: ["AwakeCore"], path: "tests/AwakeCoreTests"),
    ]
)
