// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LangSwap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "LangSwap",
            targets: ["LangSwap"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LangSwap",
            path: "Sources/LangSwap",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "LangSwapTests",
            dependencies: ["LangSwap"],
            path: "Tests/LangSwapTests"
        )
    ]
)
