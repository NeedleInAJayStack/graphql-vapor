import GraphQL

public struct GraphQLConfig<WebSocketInit: Equatable & Codable & Sendable>: Sendable {
    public let allowGet: Bool
    public let ide: IDE
    public let websocket: WebSocket
    public let additionalValidationRules: [@Sendable (ValidationContext) -> Visitor]

    public init(
        allowGet: Bool = true,
        ide: IDE = .graphiql,
        websocket: WebSocket = .init(
            // Including this strongly-typed argument is required to avoid compiler failures on Swift 6.2.3.
            onWebsocketInit: { (_: EmptyWebsocketInit) in }
        ),
        additionalValidationRules: [@Sendable (ValidationContext) -> Visitor] = []
    ) {
        self.allowGet = allowGet
        self.additionalValidationRules = additionalValidationRules
        self.ide = ide
        self.websocket = websocket
    }

    public struct IDE: Sendable {
        public static var graphiql: Self { .init(type: .graphiql) }
        public static var none: Self { .init(type: .none) }

        let type: IDEType
        enum IDEType {
            case graphiql
            case none
        }
    }

    public struct WebSocket: Sendable {
        /// A custom callback run during `connection_init` resolution that allows authorization using the `payload`.
        /// Throw from this closure to indicate that authorization has failed.
        public let onWebsocketInit: @Sendable (WebSocketInit) async throws -> Void

        public init(
            onWebsocketInit: @Sendable @escaping (WebSocketInit) async throws -> Void = { (_: EmptyWebsocketInit) in }
        ) {
            self.onWebsocketInit = onWebsocketInit
        }
    }
}
