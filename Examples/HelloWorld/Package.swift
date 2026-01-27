// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HelloWorld",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(name: "graphql-vapor", path: "../../"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/GraphQLSwift/GraphQL.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorld",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "GraphQLVapor", package: "graphql-vapor"),
                .product(name: "GraphQL", package: "GraphQL"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
    ]
)
