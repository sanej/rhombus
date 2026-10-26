// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "RhombusCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "RhombusCore", targets: ["RhombusCore"])],
    targets: [
        .target(name: "RhombusCore"),
        .testTarget(name: "RhombusCoreTests", dependencies: ["RhombusCore"]),
    ]
)
