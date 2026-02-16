import GraphQL
import Vapor

/// Configuration options for GraphQLVapor
public struct GraphQLConfig<
    WebSocketInit: Equatable & Codable & Sendable,
    WebSocketInitResult: Sendable
>: Sendable {
    let allowGet: Bool
    let allowMissingAcceptHeader: Bool
    let maxBodySize: ByteCount?
    let ide: IDE
    let subscriptionProtocols: Set<SubscriptionProtocol>
    let websocket: WebSocket
    let additionalValidationRules: [@Sendable (ValidationContext) -> Visitor]

    /// Configuration options for GraphQLVapor
    /// - Parameters:
    ///   - allowGet: Whether to allow GraphQL queries via `GET` requests.
    ///   - allowMissingAcceptHeader: Whether to allow clients to omit "Accept" headers and default to `application/graphql-response+json` encoded responses.
    ///   - maxBodySize: The maximum size of GraphQL requests in bytes. If not provided, this uses the default [`app.routes.defaultMaxBodySize`](https://docs.vapor.codes/basics/routing/#body-streaming)
    ///   - ide: The IDE to expose
    ///   - subscriptionProtocols: Protocols used to support GraphQL subscription requests
    ///   - websocket: WebSocket-specific configuration
    ///   - additionalValidationRules: Additional validation rules to apply to requests. The default GraphQL validation rules are always applied.
    public init(
        allowGet: Bool = true,
        allowMissingAcceptHeader: Bool = false,
        maxBodySize: ByteCount? = nil,
        ide: IDE = .graphiql,
        subscriptionProtocols: Set<SubscriptionProtocol> = [],
        websocket: WebSocket = .init(
            // Including this strongly-typed argument is required to avoid compiler failures on Swift 6.2.3.
            onWebSocketInit: { (_: EmptyWebSocketInit, _: Request) in }
        ),
        additionalValidationRules: [@Sendable (ValidationContext) -> Visitor] = []
    ) {
        self.allowGet = allowGet
        self.allowMissingAcceptHeader = allowMissingAcceptHeader
        self.maxBodySize = maxBodySize
        self.additionalValidationRules = additionalValidationRules
        self.ide = ide
        self.subscriptionProtocols = subscriptionProtocols
        self.websocket = websocket
    }

    public struct IDE: Sendable, Equatable {
        /// GraphiQL: https://github.com/graphql/graphiql
        public static var graphiql: Self {
            .init(type: .graphiql)
        }

        /// Do not expose a GraphQL IDE
        public static var none: Self {
            .init(type: .none)
        }

        let type: IDEType
        enum IDEType {
            case graphiql
            case none
        }
    }

    public struct SubscriptionProtocol: Sendable, Hashable {
        /// Expose GraphQL subscriptions over WebSockets
        public static var websocket: Self {
            .init(type: .websocket)
        }

        let type: SubscriptionProtocolType
        enum SubscriptionProtocolType {
            case websocket
        }
    }

    public struct WebSocket: Sendable {
        let onWebSocketInit: @Sendable (WebSocketInit, Request) async throws -> WebSocketInitResult

        /// GraphQL over WebSocket configuration
        /// - Parameter onWebSocketInit: A custom callback run during `connection_init` resolution that allows
        /// authorization using the `payload` field of the `connection_init` message.
        /// Throw from this closure to indicate that authorization has failed.
        public init(
            onWebSocketInit: @Sendable @escaping (WebSocketInit, Request) async throws -> WebSocketInitResult = { (_: EmptyWebSocketInit, _: Request) in }
        ) {
            self.onWebSocketInit = onWebSocketInit
        }
    }
}
