/// Supported websocket sub-protocols
enum WebSocketSubProtocol: String, Codable, CaseIterable {
    case graphqlTransportWs = "graphql-transport-ws"
    case graphqlWs = "graphql-ws"
}
