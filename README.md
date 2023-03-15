# OBSwiftSocket

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FOBSwiftSocket%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/edonv/OBSwiftSocket)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FOBSwiftSocket%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/edonv/OBSwiftSocket)

`OBSwiftSocket` is a Swift library to be used for communication with [OBS Studio](https://obsproject.com/) via [obs-websocket](https://github.com/obsproject/obs-websocket) (v5).

- obs-websocket v5 specification: https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md

## IMPORTANT

OBSwiftSocket is currently on pause until I have more time to work on it again. It mostly works, but has some issues that I'm trying to work out. In the interim, create an Issue if something urgently needs to be fixed and I'll see what I can do!

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

- [ ] Make Batch Requests easier to work with.
