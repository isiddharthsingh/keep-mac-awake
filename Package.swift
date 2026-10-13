// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Awake",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .target(name: "AwakeCore", path: "src/AwakeCore"),
        .executableTarget(
            name: "Awake",
            dependencies: ["AwakeCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "src/Awake",
            // build-app.sh copies Sparkle.framework into the bundle's Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "AwakeCoreTests", dependencies: ["AwakeCore"], path: "tests/AwakeCoreTests"),
    ]
)
