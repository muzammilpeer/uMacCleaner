// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "uMacCleaner",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacCleaner", targets: ["MacCleaner"]),
        .executable(name: "mclean", targets: ["mclean"])
    ],
    targets: [
        .target(name: "CleanerCore"),
        .executableTarget(name: "MacCleaner", dependencies: ["CleanerCore"]),
        .executableTarget(name: "mclean", dependencies: ["CleanerCore"]),
        .testTarget(name: "CleanerCoreTests", dependencies: ["CleanerCore"])
    ]
)
