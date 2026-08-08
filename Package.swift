// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "NSWindowBuilder",

    platforms: [
        .macOS(.v13)
    ],

    products: [
        .library(
            name: "NSWindowBuilder",
            targets: ["NSWindowBuilder"]
        ),
    ],

    targets: [
        .target(
            name: "NSWindowBuilder"
        ),
    ]
)
