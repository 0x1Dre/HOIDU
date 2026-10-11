// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CCTVCore",
    defaultLocalization: "de",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CCTVCore", targets: ["CCTVCore"])
    ],
    targets: [
        .target(
            name: "CCTVCore",
            path: "Sources/CCTVCore"
        ),
        .testTarget(
            name: "CCTVCoreTests",
            dependencies: ["CCTVCore"],
            path: "Tests/CCTVCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
