import Testing
import VaporTesting
import GraphQL
import GraphQLVapor

@Suite("GraphQLVapor Tests")
struct GraphQLVaporTests {
    @Test func basicQuery() async throws {
        try await withApp { app in
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

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(GraphQLRequest(query: "{ hello }"))
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["hello"] == "World")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func queryWithVariables() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "greet": GraphQLField(
                            type: GraphQLString,
                            args: [
                                "name": GraphQLArgument(type: GraphQLString)
                            ],
                            resolve: { _, args, _, _ in
                                guard let name = args["name"].string else {
                                    return "Hello, stranger"
                                }
                                return "Hello, \(name)"
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(
                    GraphQLRequest(
                        query: "query Greet($name: String) { greet(name: $name) }",
                        variables: ["name": "Alice"]
                    )
                )
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["greet"] == "Hello, Alice")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func queryWithContext() async throws {
        try await withApp { app in
            struct Context: Sendable {
                let message: String
            }

            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "contextMessage": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, context, _ in
                                guard let ctx = context as? Context else {
                                    throw GraphQLError(message: "Invalid context")
                                }
                                return ctx.message
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: Context(message: "Hello from context!"))
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(GraphQLRequest(query: "{ contextMessage }"))
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["contextMessage"] == "Hello from context!")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func jsonContent() async throws {
        try await withApp { app in
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

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                req.headers.replaceOrAdd(name: .accept, value: HTTPMediaType.json.serialize())
                try req.content.encode(GraphQLRequest(query: "{ hello }"), as: .json)
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .json)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["hello"] == "World")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func errorHandling() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "error": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, _, _ in
                                throw GraphQLError(message: "Something went wrong")
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(GraphQLRequest(query: "{ error }"))
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(!response.errors.isEmpty)
                #expect(response.errors.first?.message == "Something went wrong")
            }
        }
    }

    @Test func getRequest() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "test": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, _, _ in
                                "GET works"
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.get("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.GET, "/graphql?query=%7Btest%7D") { _ in
            } afterResponse: { res in
                #expect(res.status == .ok)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["test"] == "GET works")
                #expect(response.errors.isEmpty)
            }
        }
    }

    struct EmptyContext: Sendable {}
}
