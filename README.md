# OBSwiftSocket
[![Swift Version](https://img.shields.io/badge/Swift-v5.3-orange)](https://github.com/tterb/atomic-design-ui/blob/master/LICENSEs)
![License](https://img.shields.io/github/license/edonv/OBSwiftSocket)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FOBSwiftSocket%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/edonv/OBSwiftSocket)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FOBSwiftSocket%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/edonv/OBSwiftSocket)

`OBSwiftSocket` is a Swift library to be used for communication with [OBS Studio](https://obsproject.com/) via [obs-websocket](https://github.com/obsproject/obs-websocket) (v5).

- obs-websocket v5 specification: https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md

## Installation

### Swift Package Manager

Add `OBSwiftSocket` as a dependency:

```swift
import PackageDescription
let package = Package(
    name: "YourApp",
    dependencies: [
        .package(
            name: "OBSwiftSocket",
            url: "https://github.com/edonv/OBSwiftSocket.git",
            .upToNextMajor(from: "1.0.0"))
    ]
)
```

## Requirements
- Swift 5.3 or later
- iOS 13.0 or later
- macOS 10.15 or later

## Usage

Examples coming soon!

## License

`OBSwiftSocket` is released under the MIT license. See [LICENSE](https://github.com/edonv/OBSwiftSocket/blob/main/LICENSE) for details.

## To-Do's

[ ] Make Batch Requests easier to work with.
