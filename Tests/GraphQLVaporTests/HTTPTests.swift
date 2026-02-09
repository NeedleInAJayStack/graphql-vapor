import GraphQL
import GraphQLTransportWS
@testable import GraphQLVapor
import GraphQLWS
import Testing
import VaporTesting

@Suite
struct HTTPTests {
    @Test func query() async throws {
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(GraphQLRequest(query: "{ hello }"))
            } afterResponse: { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .jsonGraphQL)

                let result = try response.content.decode(GraphQLResult.self)
                #expect(result.data?["hello"] == "World")
                #expect(result.errors.isEmpty)
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
                                "name": GraphQLArgument(type: GraphQLString),
                            ],
                            resolve: { _, args, _, _ in
                                guard let name = args["name"].string else {
                                    return "Hello, stranger"
                                }
                                return "Hello, \(name)"
                            }
                        ),
                    ]
                )
            )

            app.graphql(schema: schema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(
                    GraphQLRequest(
                        query: "query Greet($name: String) { greet(name: $name) }",
                        variables: ["name": "Alice"]
                    )
                )
            } afterResponse: { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .jsonGraphQL)

                let result = try response.content.decode(GraphQLResult.self)
                #expect(result.data?["greet"] == "Hello, Alice")
                #expect(result.errors.isEmpty)
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
                        ),
                    ]
                )
            )

            app.graphql(schema: schema) { _ in
                Context(message: "Hello from context!")
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(GraphQLRequest(query: "{ contextMessage }"))
            } afterResponse: { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .jsonGraphQL)

                let result = try response.content.decode(GraphQLResult.self)
                #expect(result.data?["contextMessage"] == "Hello from context!")
                #expect(result.errors.isEmpty)
            }
        }
    }

    @Test func jsonAcceptHeader() async throws {
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonHeaders) { req in
                try req.content.encode(GraphQLRequest(query: "{ hello }"), as: .json)
            } afterResponse: { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .json)

                let result = try response.content.decode(GraphQLResult.self)
                #expect(result.data?["hello"] == "World")
                #expect(result.errors.isEmpty)
            }
        }
    }

    @Test func noAcceptHeader() async throws {
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: [:]) { req in
                try req.content.encode(GraphQLRequest(query: "{ hello }"), as: .json)
            } afterResponse: { response in
                #expect(response.status == .notAcceptable)
            }
        }
    }

    @Test func defaultAcceptHeader() async throws {
        try await withApp { app in
            app.graphql(schema: helloWorldSchema, config: .init(allowMissingAcceptHeader: true)) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: [:]) { req in
                try req.content.encode(GraphQLRequest(query: "{ hello }"), as: .json)
            } afterResponse: { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .jsonGraphQL)

                let result = try response.content.decode(GraphQLResult.self)
                #expect(result.data?["hello"] == "World")
                #expect(result.errors.isEmpty)
            }
        }
    }

    @Test func allowGetRequest() async throws {
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.GET, "/graphql?query=%7Bhello%7D", headers: jsonGraphQLHeaders) { _ in
            } afterResponse: { response in
                #expect(response.status == .ok)

                let response = try response.content.decode(GraphQLResult.self)
                #expect(response.data?["hello"] == "World")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func disallowGetRequest() async throws {
        try await withApp { app in
            app.graphql(
                schema: helloWorldSchema,
                config: .init(
                    allowGet: false
                )
            ) { _ in
                EmptyContext()
            }

            try await app.test(.GET, "/graphql?query=%7Bhello%7D", headers: jsonGraphQLHeaders) { _ in
            } afterResponse: { response in
                #expect(response.status == .methodNotAllowed)
            }
        }
    }

    @Test func graphiql() async throws {
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.GET, "/graphql") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == GraphiQLHandler.html(url: "/graphql", subscriptionUrl: nil))
            }
        }
    }

    @Test func graphiqlSubscription() async throws {
        try await withApp { app in
            app.graphql(schema: helloWorldSchema, config: .init(subscriptionProtocols: [.websocket])) { _ in
                EmptyContext()
            }

            try await app.test(.GET, "/graphql") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == GraphiQLHandler.html(url: "/graphql", subscriptionUrl: "/graphql"))
            }
        }
    }
}
