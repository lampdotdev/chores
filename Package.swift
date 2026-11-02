// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Chores",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Chores", path: "Sources")]
)
