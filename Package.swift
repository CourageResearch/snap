// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snap",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "Snap",
            path: "Sources"
        )
    ]
)
