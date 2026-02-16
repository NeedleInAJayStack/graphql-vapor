# GraphQLVapor

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGraphQLSwift%2Fgraphql-vapor%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/GraphQLSwift/graphql-vapor)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGraphQLSwift%2Fgraphql-vapor%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/GraphQLSwift/graphql-vapor)

A Swift library for integrating [GraphQL](https://github.com/GraphQLSwift/GraphQL) with [Vapor](https://github.com/vapor/vapor), enabling you to easily expose GraphQL APIs in your Vapor applications.

## Features

- Simple integration of GraphQL schemas with Vapor routing
- Compatibility with the [GraphQL over HTTP spec](https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md)
- Subscription support using WebSockets, with support for [`graphql-transport-ws`](https://github.com/GraphQLSwift/GraphQLTransportWS) and [`graphql-ws`](https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md) subprotocols
- Built-in [GraphiQL](https://github.com/graphql/graphiql) IDE

## Installation

Add GraphQLVapor as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NeedleInAJayStack/graphql-vapor.git", from: "1.0.0"),
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "GraphQLVapor", package: "graphql-vapor"),
    ]
)
```

## Usage

### Basic Example

```swift
import GraphQL
import GraphQLVapor
import Vapor

// Define your GraphQL schema
// To construct schemas, consider using `Graphiti` or `graphql-generator`
let schema = try GraphQLSchema(
    query: GraphQLObjectType(
        name: "Query",
        fields: [
            "hello": GraphQLField(
                type: GraphQLString,
                resolve: { _, _, _, _ in
                    "World"
                }
            )
        ]
    )
)

// Define your Context
struct GraphQLContext: Sendable {}

// Register GraphQL to the Vapor Application
app.graphql(schema: schema) { _ in
    return GraphQLContext()
}
```

Now just run the application! You can view the GraphiQL IDE at `/graphql`, or query directly using `GET` or `POST`:

```bash
curl -X POST http://localhost:8080/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ hello }"}'
```

Response:
```json
{
  "data": {
    "hello": "World"
  }
}
```

See the `RouteBuilder.graphql` function documentation for advanced configuration options.

### Computing GraphQL Context

The required closure in the `graphql` function is used to compute the `GraphQLContext` object, which is injected into each GraphQL resolver. The `inputs` argument passes in data from the request so that the Context can be created dynamically:

```swift
app.graphql(schema: schema) { inputs in
    return GraphQLContext(
        userID: inputs.vaporRequest.auth.userID,
        logger: inputs.vaporRequest.logger,
        debug: inputs.vaporRequest.headers[.init("debug")!] != nil,
        operationName: inputs.graphQLRequest.operationName
    )
}
```
