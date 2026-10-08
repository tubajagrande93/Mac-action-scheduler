// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "MacActionScheduler",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MacActionScheduler"
        ),
        .testTarget(
            name: "MacActionSchedulerTests",
            dependencies: ["MacActionScheduler"]
        )
    ],
    swiftLanguageModes: [.v6]
)
