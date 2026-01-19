// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GraphQLVapor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GraphQLVapor",
            targets: ["GraphQLVapor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/GraphQLSwift/GraphQL.git", from: "4.0.0"),
        .package(url: "https://github.com/GraphQLSwift/GraphQLTransportWS.git", from: "0.2.1"),
        .package(url: "https://github.com/GraphQLSwift/GraphQLWS.git", from: "0.2.1"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "GraphQLVapor",
            dependencies: [
                .product(name: "GraphQL", package: "GraphQL"),
                .product(name: "GraphQLTransportWS", package: "GraphQLTransportWS"),
                .product(name: "GraphQLWS", package: "GraphQLWS"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "GraphQLVaporTests",
            dependencies: [
                "GraphQLVapor",
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
