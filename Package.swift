// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenLid",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "OpenLid", targets: ["OpenLid"])],
    targets: [
        .target(name: "FoldCore"),
        .executableTarget(name: "OpenLid", dependencies: ["FoldCore"]),
        .executableTarget(name: "FoldCoreChecks", dependencies: ["FoldCore"], path: "Tests/FoldCoreTests")
    ]
)
