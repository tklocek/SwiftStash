// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftStash",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        // watchOS 9 is the LocalAuthentication floor — the biometric/Secure Enclave
        // APIs in Keychain/Crypto need LAContext.
        .watchOS(.v9),
        .visionOS(.v1),
        .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "SwiftStash",
            targets: ["SwiftStash"]
        ),
        .library(
            name: "SwiftStashUI",
            targets: ["SwiftStashUI"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftStash",
            swiftSettings: [
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "SwiftStashUI",
            dependencies: ["SwiftStash"],
            swiftSettings: [
                .strictMemorySafety()
            ]
        ),
        .testTarget(
            name: "SwiftStashTests",
            dependencies: ["SwiftStash", "SwiftStashUI"],
            exclude: ["Test Plan"]
        ),
    ],
    swiftLanguageModes: [.v6],
)
