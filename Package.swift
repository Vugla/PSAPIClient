// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PSAPIClient",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PSAPIClient",
            targets: ["PSAPIClient"]),
    ],
    dependencies: [
         .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.4.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "PSAPIClient",
            dependencies: ["Alamofire"]),
        .testTarget(
            name: "PSAPIClientTests",
            dependencies: ["PSAPIClient"]),
    ]
)
