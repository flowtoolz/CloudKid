// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "CloudKid",
    platforms: [.iOS(.v11), .tvOS(.v11), .macOS(.v12)],
    products: [
        .library(
            name: "CloudKid",
            targets: ["CloudKid"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/flowtoolz/FoundationToolz.git",
            exact: "0.1.2"
        ),
        .package(
            url: "https://github.com/codeface-io/SwiftObserver.git",
            exact: "7.0.4"
        ),
        .package(
            url: "https://github.com/flowtoolz/SwiftyToolz.git",
            exact: "0.2.0"
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
