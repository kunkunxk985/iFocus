// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "iFocus",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "iFocus", targets: ["iFocus"]),
        .library(name: "iFocusCore", targets: ["iFocusCore"]),
    ],
    targets: [
        // Pure logic — unit-testable without AppKit/SwiftUI windows.
        .target(
            name: "iFocusCore",
            path: "Sources/iFocusCore"
        ),
        .executableTarget(
            name: "iFocus",
            dependencies: ["iFocusCore"],
            path: "Sources/iFocus",
            resources: [.copy("AppIcon.icns")]
        ),
        .testTarget(
            name: "iFocusTests",
            // iFocus module: TaskStore + app types; iFocusCore: pure helpers.
            dependencies: ["iFocusCore", "iFocus"],
            path: "Tests/iFocusTests"
        ),
    ]
)
