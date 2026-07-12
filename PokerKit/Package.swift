// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PokerKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PokerKit", targets: ["PokerKit"]),
    ],
    targets: [
        .target(name: "PokerKit"),
        .testTarget(name: "PokerKitTests", dependencies: ["PokerKit"]),
    ]
)
