// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "CloudKid",
    products: [
        .library(name: "CloudKid",
                 targets: ["CloudKid"]),
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
        ),
        .package(
            url: "https://github.com/mxcl/PromiseKit.git",
            .upToNextMajor(from: "6.13.1")
        ),
    ],
    targets: [
        .target(name: "CloudKid",
                dependencies: [
			"FoundationToolz",
			"SwiftObserver",
			"SwiftyToolz",
			"PromiseKit"
		],
                path: "Code"),
    ]
)
