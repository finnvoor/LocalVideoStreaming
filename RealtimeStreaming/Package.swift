// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RealtimeStreaming",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RealtimeStreaming", targets: ["RealtimeStreaming"])],
    targets: [.target(name: "RealtimeStreaming")]
)
