import GraphQL
import Vapor

public extension RoutesBuilder {
    /// Registers graphql routes that respond using the provided schema.
    ///
    /// The resulting routes adhere to the [GraphQL over HTTP spec](https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md).
    /// The configured IDE is available by making a `GET` request to the path with no query parameter.
    ///
    /// If enabled, WebSocket requests to the path are accepted and support the
    /// [`graphql-transport-ws`](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md)
    /// and [`graphql-ws`](https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md)
    /// subprotocols.
    ///
    /// - Parameters:
    ///   - path: The route that should respond to GraphQL requests. Both `GET` and `POST` routes are registered.
    ///   - schema: The GraphQL schema that should be used to respond to requests.
    ///   - rootValue: The `rootValue` GraphQL execution arg. This is the object passed to the root resolvers.
    ///   - config: GraphQL Handler configuration options. See type documentation for details.
    ///   - computeContext: A closure used to compute the GraphQL context from incoming requests. This must be provided.
    func graphql<
        Context: Sendable,
        WebSocketInit: Equatable & Codable & Sendable,
        WebSocketInitResult: Sendable
    >(
        _ path: [PathComponent] = ["graphql"],
        schema: GraphQLSchema,
        rootValue: any Sendable = (),
        config: GraphQLConfig<WebSocketInit, WebSocketInitResult> = GraphQLConfig<EmptyWebSocketInit, Void>(),
        computeContext: @Sendable @escaping (GraphQLContextComputationInputs<WebSocketInitResult>) async throws -> Context
    ) {
        ContentConfiguration.global.use(encoder: GraphQLJSONEncoder(), for: .jsonGraphQL)
        ContentConfiguration.global.use(decoder: JSONDecoder(), for: .jsonGraphQL)

        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#request
        let handler = GraphQLHandler<Context, WebSocketInit, WebSocketInitResult>(schema: schema, rootValue: rootValue, config: config, computeContext: computeContext)
        get(path) { request in
            // WebSocket handling
            if
                config.subscriptionProtocols.contains(.websocket),
                request.headers.connection?.value.lowercased() == "upgrade"
            {
                return try await handler.handleWebSocket(request: request)
            }

            // Get requests without a `query` parameter are considered to be IDE requests
            if request.url.query == nil || !(request.url.query?.contains("query") ?? true) {
                switch config.ide.type {
                case .graphiql:
                    return try await GraphiQLHandler.respond(
                        url: request.url.string,
                        subscriptionUrl: config.subscriptionProtocols.contains(.websocket) ? request.url.string : nil
                    )
                case .none:
                    // Let this get caught by the graphQLRequest decoding
                    break
                }
            }

            // Normal GET request handling
            guard config.allowGet else {
                throw Abort(.methodNotAllowed, reason: "GET requests are disallowed")
            }
            return try await handler.handleGet(request: request)
        }
        on(.POST, path, body: .collect(maxSize: config.maxBodySize)) { request in
            try await handler.handlePost(request: request)
        }
    }
}

/// Request metadata that can be used to construct a GraphQL context
public struct GraphQLContextComputationInputs<
    WebSocketInitResult: Sendable
>: Sendable {
    /// The Vapor request that initiated the GraphQL request. In WebSockets, this is the upgrade GET request.
    public let vaporRequest: Request

    /// The decoded GraphQL request, including the raw query, variables, and more
    public let graphQLRequest: GraphQLRequest

    /// The result of the WebSocket's initialization closure. This can be used to customize GraphQL context creation based on the init
    /// message metadata as opposed to only the upgrade request. In non-WebSocket contexts, this is nil.
    public let websocketInitResult: WebSocketInitResult?
}
