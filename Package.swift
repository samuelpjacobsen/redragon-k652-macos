// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "K652",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "K652App", targets: ["K652App"]),
        .executable(name: "k652ctl", targets: ["k652ctl"]),
    ],
    targets: [
        .target(name: "K652Kit", linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "K652App", dependencies: ["K652Kit"]),
        .executableTarget(name: "k652ctl", dependencies: ["K652Kit"]),
        .testTarget(name: "K652KitTests", dependencies: ["K652Kit"]),
    ],
    swiftLanguageModes: [.v5]
)
