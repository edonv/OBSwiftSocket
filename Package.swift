// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OBSwiftSocket",
    platforms: [
        .iOS(SupportedPlatform.IOSVersion.v13),
        .macOS(SupportedPlatform.MacOSVersion.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "OBSwiftSocket",
            targets: ["OBSwiftSocket"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
//        .package(
//            name: "swift-format",
//            url: "https://github.com/apple/swift-format.git",
//            .upToNextMinor(from: "0.50300.0")),
        .package(url: "https://github.com/edonv/JSONValue.git",
                 branch: "main"),
        .package(url: "https://github.com/edonv/WSPublisher.git",
                 branch: "main"),
        .package(url: "https://github.com/hirotakan/MessagePacker.git",
                 .upToNextMajor(from: "0.0.0")),
        .package(url: "https://github.com/edonv/CommonExtensions.git",
                 branch: "main"),
        .package(url: "https://github.com/edonv/AsyncCompatibilityKit.git",
                 branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "OBSwiftSocket",
            dependencies: [
                "JSONValue",
                "WSPublisher",
                "MessagePacker",
                "AsyncCompatibilityKit",
                .product(name: "CombineExtensions", package: "CommonExtensions")
            ]
        ),
        .executableTarget(
            name: "Scripts",
            dependencies: ["JSONValue"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "OBSwiftSocketTests",
            dependencies: [
                "OBSwiftSocket",
                .product(name: "CombineExtensions", package: "CommonExtensions")
            ]),
    ]
)
