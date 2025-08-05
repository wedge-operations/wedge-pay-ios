// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "wedge-pay-ios",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "wedge-pay-ios",
            targets: ["wedge_pay_ios"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "wedge_pay_ios",
            dependencies: [],
            path: "Sources/wedge_pay_ios"),
        .testTarget(
            name: "wedge_pay_iosTests",
            dependencies: ["wedge_pay_ios"],
            path: "Tests/wedge_pay_iosTests"),
    ]
)