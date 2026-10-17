// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SketchCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SketchCore", targets: ["SketchCore"])
    ],
    targets: [
        .target(name: "SketchCore"),
        .testTarget(name: "SketchCoreTests", dependencies: ["SketchCore"])
    ]
)
