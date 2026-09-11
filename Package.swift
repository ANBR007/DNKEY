// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DNKEY",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DNKEY",
            path: "Sources/DNKEY"
        )
    ]
)
