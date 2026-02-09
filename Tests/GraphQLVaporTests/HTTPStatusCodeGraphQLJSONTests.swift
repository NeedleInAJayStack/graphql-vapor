import Foundation
import GraphQL
import GraphQLTransportWS
@testable import GraphQLVapor
import GraphQLWS
import NIOFoundationCompat
import Testing
import Vapor
import VaporTesting

/// Validates status code behavior for the `application/graphql-response+json` media type.
///
/// https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#applicationgraphql-responsejson
@Suite
struct HTTPStatusCodeGraphQLJSONTests {
    @Test func parsingFailureGivesBadRequest() async throws {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#json-parsing-failure-1
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(#"{"query":"#)
            } afterResponse: { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func invalidParametersGivesBadRequest() async throws {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#invalid-parameters-1
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(["qeury": "{__typename}"])
            } afterResponse: { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func documentParsingFailureGivesBadRequest() async throws {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#document-parsing-failure-1
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(GraphQLRequest(
                    query: "{"
                ))
            } afterResponse: { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func documentValidationFailureGivesBadRequest() async throws {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#document-validation-failure-1
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                // Fails "No Unused Variables" validation rule
                try req.content.encode(GraphQLRequest(
                    query: "query A($name: String) { hello }"
                ))
            } afterResponse: { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func operationCannotBeDeterminedGivesBadRequest() async throws {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#operation-cannot-be-determined-1
        try await withApp { app in
            app.graphql(schema: helloWorldSchema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(GraphQLRequest(
                    query: "abc { hello }"
                ))
            } afterResponse: { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func variableCoercionFailureGivesBadRequest() async throws {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#variable-coercion-failure-1
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "get": GraphQLField(
                            type: GraphQLString,
                            args: [
                                "name": GraphQLArgument(type: GraphQLString),
                            ],
                            resolve: { _, args, _, _ in
                                guard let name = args["name"].string else {
                                    throw GraphQLError(message: "Name arg is required")
                                }
                                return name
                            }
                        ),
                    ]
                )
            )
            app.graphql(schema: schema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(GraphQLRequest(
                    query: "query getName($name: String!) { get(name: $name) }",
                    variables: ["name": .null]
                ))
            } afterResponse: { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func fieldErrorGivesOk() async throws {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#field-errors-encountered-during-execution-1
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
                        ),
                    ]
                )
            )
            app.graphql(schema: schema) { _ in
                EmptyContext()
            }

            try await app.test(.POST, "/graphql", headers: jsonGraphQLHeaders) { req in
                try req.content.encode(GraphQLRequest(query: "{ error }"))
            } afterResponse: { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .jsonGraphQL)

                let response = try response.content.decode(GraphQLResult.self)
                #expect(!response.errors.isEmpty)
                #expect(response.errors.first?.message == "Something went wrong")
            }
        }
    }
}
