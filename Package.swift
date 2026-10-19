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
            resources: [.copy("AppIcon.icns")],
            // SwiftPM's macOS linker invocation can omit -platform_version, which
            // makes ld record the deployment target as both minos and SDK. Keep
            // these values in sync with the selected Xcode/macOS SDK.
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-platform_version",
                    "-Xlinker", "macos",
                    "-Xlinker", "13.0",
                    "-Xlinker", "27.0",
                ]),
            ]
        ),
        .testTarget(
            name: "iFocusTests",
            // iFocus module: TaskStore + app types; iFocusCore: pure helpers.
            dependencies: ["iFocusCore", "iFocus"],
            path: "Tests/iFocusTests"
        ),
    ]
)
