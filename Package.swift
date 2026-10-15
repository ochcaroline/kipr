// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kipr",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Kipr", targets: ["Kipr"]),
    ],
    targets: [
        .target(name: "KiprCore"),
        .executableTarget(name: "Kipr", dependencies: ["KiprCore"]),
        .executableTarget(name: "KiprTests", dependencies: ["KiprCore"]),
    ]
)
