// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Swift Package Manager integration for dicom_toolkit.
//
// Flutter looks for this manifest at `ios/<plugin_name>/Package.swift` and has
// its generated `FlutterGeneratedPluginSwiftPackage` depend on the library
// product below. The product name is the hyphenated plugin name (Flutter uses
// it as the framework's CFBundleIdentifier, which cannot contain underscores).
//
// The Rust core ships **prebuilt and dynamic**:
//   * SwiftPM cannot build Rust, so the core has to be a binary target — the
//     same way `web/pkg` ships prebuilt WASM.
//   * It must be dynamic. The flutter_rust_bridge entry points are resolved by
//     name at runtime, so nothing references them at link time; a static
//     library would be dead-stripped out of the app (see the README's
//     "iOS and macOS" section).
//
// Rebuild it with `tool/rebuild_xcframework.sh` and commit the result whenever
// `rust/src/**` changes.

let package = Package(
    name: "dicom_toolkit",
    platforms: [
        .iOS("11.0")
    ],
    products: [
        .library(name: "dicom-toolkit", targets: ["dicom_toolkit"])
    ],
    targets: [
        .binaryTarget(
            name: "dicom_toolkit",
            path: "dicom_toolkit.xcframework"
        )
    ]
)
