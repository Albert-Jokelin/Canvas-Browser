// swift-tools-version: 5.9
import PackageDescription
import Foundation

let packagePath = URL(fileURLWithPath: #file).deletingLastPathComponent().path
let infoPlistPath = "\(packagePath)/CanvasBrowser/Info.plist"

let package = Package(
    name: "CanvasBrowser",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CanvasBrowser",
            targets: ["CanvasBrowser"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CanvasBrowser",
            dependencies: [],
            path: "CanvasBrowser",
            exclude: ["Resources"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlistPath])
            ]
        ),
        .testTarget(
            name: "CanvasBrowserTests",
            dependencies: [],
            path: "Tests/CanvasBrowserTests"
        )
    ]
)
