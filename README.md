# GraphQLVapor

A Swift library for integrating [GraphQL](https://github.com/GraphQLSwift/GraphQL) with [Vapor](https://github.com/vapor/vapor), enabling you to easily expose GraphQL endpoints in your Vapor applications.

## Features

- Simple integration of GraphQL schemas with Vapor routing
- Support for both GET and POST requests
- Generic context value support for passing request-specific data to resolvers
- Automatic encoding/decoding of GraphQL requests and responses

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

// Create a GraphQL handler
let graphQLHandler = GraphQLHandler(schema: schema)

// Configure routes
func routes(_ app: Application) throws {
    app.post("graphql") { req in
        let context = GraphQLContext()
        return try await graphQLHandler.handle(req, context: context)
    }
}
```

Now you can query your GraphQL endpoint:

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
