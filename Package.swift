// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "CloudKid",
    platforms: [.iOS(.v9), .tvOS(.v9), .macOS(.v10_12)],
    products: [
        .library(
            name: "CloudKid",
            targets: ["CloudKid"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/flowtoolz/FoundationToolz.git",
            .branch("master")
        ),
        .package(
            url: "https://github.com/flowtoolz/SwiftObserver.git",
            .branch("master")
        ),
        .package(
            url: "https://github.com/flowtoolz/SwiftyToolz.git",
            .branch("master")
        )
    ],
    targets: [
        .target(
            name: "CloudKid",
            dependencies: [
                "FoundationToolz",
                "SwiftObserver",
                "SwiftyToolz"
            ],
            path: "Code"
        ),
    ]
)
