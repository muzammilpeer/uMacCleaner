// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "uMacCleaner",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "uMacCleaner-GUI", targets: ["uMacCleanerGUI"]),
        .executable(name: "uMacCleaner-CLI", targets: ["uMacCleanerCLI"])
    ],
    targets: [
        .target(name: "CleanerCore"),
        .executableTarget(name: "uMacCleanerGUI", dependencies: ["CleanerCore"]),
        .executableTarget(name: "uMacCleanerCLI", dependencies: ["CleanerCore"]),
        .testTarget(name: "CleanerCoreTests", dependencies: ["CleanerCore"])
    ]
)
