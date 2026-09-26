// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CycleTimerCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "CycleTimerCore", targets: ["CycleTimerCore"])],
    targets: [
        .target(name: "CycleTimerCore", path: "Sources/CycleTimerCore"),
        .testTarget(name: "CycleTimerCoreTests", dependencies: ["CycleTimerCore"], path: "Tests/CycleTimerCoreTests")
    ]
)
