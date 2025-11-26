// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TheMet",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "TheMet",
            targets: ["TheMet"])
    ],
    targets: [
        .target(
            name: "TheMet"),
        .testTarget(
            name: "TheMetTests",
            dependencies: ["TheMet"])
    ]
)
