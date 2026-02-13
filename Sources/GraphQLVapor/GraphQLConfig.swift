import GraphQL

/// Configuration options for GraphQLVapor
public struct GraphQLConfig<
    WebSocketInit: Equatable & Codable & Sendable,
    WebSocketInitResult: Sendable
>: Sendable {
    let allowGet: Bool
    let allowMissingAcceptHeader: Bool
    let ide: IDE
    let subscriptionProtocols: Set<SubscriptionProtocol>
    let websocket: WebSocket
    let additionalValidationRules: [@Sendable (ValidationContext) -> Visitor]

    /// Configuration options for GraphQLVapor
    /// - Parameters:
    ///   - allowGet: Whether to allow GraphQL queries via `GET` requests.
    ///   - allowMissingAcceptHeader: Whether to allow clients to omit "Accept" headers and default to `application/graphql-response+json` encoded responses.
    ///   - ide: The IDE to expose
    ///   - subscriptionProtocols: Protocols used to support GraphQL subscription requests
    ///   - websocket: WebSocket-specific configuration
    ///   - additionalValidationRules: Additional validation rules to apply to requests. The default GraphQL validation rules are always applied.
    public init(
        allowGet: Bool = true,
        allowMissingAcceptHeader: Bool = false,
        ide: IDE = .graphiql,
        subscriptionProtocols: Set<SubscriptionProtocol> = [],
        websocket: WebSocket = .init(
            // Including this strongly-typed argument is required to avoid compiler failures on Swift 6.2.3.
            onWebsocketInit: { (_: EmptyWebsocketInit) in }
        ),
        additionalValidationRules: [@Sendable (ValidationContext) -> Visitor] = []
    ) {
        self.allowGet = allowGet
        self.allowMissingAcceptHeader = allowMissingAcceptHeader
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
        let onWebsocketInit: @Sendable (WebSocketInit) async throws -> WebSocketInitResult

        /// GraphQL over WebSocket configuration
        /// - Parameter onWebsocketInit: A custom callback run during `connection_init` resolution that allows
        /// authorization using the `payload` field of the `connection_init` message.
        /// Throw from this closure to indicate that authorization has failed.
        public init(
            onWebsocketInit: @Sendable @escaping (WebSocketInit) async throws -> WebSocketInitResult = { (_: EmptyWebsocketInit) in }
        ) {
            self.onWebsocketInit = onWebsocketInit
        }
    }
}
