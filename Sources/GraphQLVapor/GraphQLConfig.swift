import GraphQL

public struct GraphQLConfig<WebSocketInit: Equatable & Codable & Sendable>: Sendable {
    public let allowGet: Bool
    public let allowMissingAcceptHeader: Bool
    public let ide: IDE
    public let websocket: WebSocket
    public let additionalValidationRules: [@Sendable (ValidationContext) -> Visitor]

    /// Configuration for GraphQL responses
    /// - Parameters:
    ///   - allowGet: Whether to allow GraphQL queries via `GET` requests.
    ///   - allowMissingAcceptHeader: Whether to allow clients to omit "Accept" headers and default to `application/graphql-response+json` encoded responses.
    ///   - ide: The IDE to expose
    ///   - websocket: WebSocket-specific configuration
    ///   - additionalValidationRules: Additional validation rules to apply to requests. The default GraphQL validation rules are always applied.
    public init(
        allowGet: Bool = true,
        allowMissingAcceptHeader: Bool = false,
        ide: IDE = .graphiql,
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
        self.websocket = websocket
    }

    public struct IDE: Sendable {
        /// GraphiQL: https://github.com/graphql/graphiql
        public static var graphiql: Self { .init(type: .graphiql) }

        /// Do not expose a GraphQL IDE
        public static var none: Self { .init(type: .none) }

        let type: IDEType
        enum IDEType {
            case graphiql
            case none
        }
    }

    public struct WebSocket: Sendable {
        public let onWebsocketInit: @Sendable (WebSocketInit) async throws -> Void

        /// GraphQL over WebSocket configuration
        /// - Parameter onWebsocketInit: A custom callback run during `connection_init` resolution that allows authorization using the `payload`.
        /// Throw from this closure to indicate that authorization has failed.
        public init(
            onWebsocketInit: @Sendable @escaping (WebSocketInit) async throws -> Void = { (_: EmptyWebsocketInit) in }
        ) {
            self.onWebsocketInit = onWebsocketInit
        }
    }
}
