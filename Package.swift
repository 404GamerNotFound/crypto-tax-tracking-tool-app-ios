// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CryptoBuchCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "CryptoBuchCore", targets: ["CryptoBuchCore"])],
    targets: [
        .target(name: "CryptoBuchCore", path: "crypto-tax-tracking-tool-app-ios/crypto-tax-tracking-tool-app-ios/Core"),
        .testTarget(name: "CryptoBuchCoreTests", dependencies: ["CryptoBuchCore"], path: "Tests/CryptoBuchCoreTests")
    ]
)
