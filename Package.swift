// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HermesDesktop",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HermesDesktop",
            targets: ["HermesDesktop"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "HermesDesktop",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/HermesDesktop"
        )
    ]
)
