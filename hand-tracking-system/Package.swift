// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HandTracker",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "HandTracker", targets: ["HandTracker"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HandTracker",
            dependencies: [],
            path: "Sources/HandTracker"
        )
    ]
)
