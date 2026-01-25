import GraphQL
import Vapor

public extension RoutesBuilder {
    /// Registers graphql routes that respond using the provided schema.
    ///
    /// The resulting routes adhere to the [GraphQL over HTTP spec](https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md),
    /// and support the [`graphql-transport-ws`](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md)
    /// and [`graphql-ws`](https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md)
    /// websocket subprotocols.
    ///
    /// - Parameters:
    ///   - path: The route that should respond to GraphQL requests. Both `GET` and `POST` routes are registered.
    ///   - schema: The GraphQL schema that should be used to respond to requests.
    ///   - config: GraphQL Handler configuration options. See type documentation for details.
    ///   - computeContext: A closure used to compute the GraphQL context from incoming requests. This must be provided.
    func graphql<
        Context: Sendable,
        WebSocketInit: Equatable & Codable & Sendable
    >(
        _ path: [PathComponent] = ["graphql"],
        schema: GraphQLSchema,
        config: GraphQLConfig<WebSocketInit> = GraphQLConfig<EmptyWebsocketInit>(),
        computeContext: @Sendable @escaping (Request) async throws -> Context
    ) {
        let graphqlHandler = GraphQLHandler<Context, WebSocketInit>(schema: schema, config: config)
        get(path) { req in
            let context = try await computeContext(req)
            return try await graphqlHandler.handle(req, context: context)
        }
        post(path) { req in
            let context = try await computeContext(req)
            return try await graphqlHandler.handle(req, context: context)
        }
    }
}
