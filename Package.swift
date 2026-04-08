// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VimMail",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VimMail", targets: ["VimMail"])
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", from: "0.54.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.14.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.6.1"),
    ],
    targets: [
        .executableTarget(
            name: "VimMail",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ],
            path: "Sources/VimMail"
        ),
        .testTarget(
            name: "VimMailTests",
            dependencies: ["VimMail"],
            path: "Tests/VimMailTests"
        )
    ]
)
