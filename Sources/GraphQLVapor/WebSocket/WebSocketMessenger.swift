import GraphQLTransportWS
import GraphQLWS
import WebSocketKit

/// Messenger wrapper for WebSockets
struct WebSocketMessenger: GraphQLTransportWS.Messenger, GraphQLWS.Messenger {
    let websocket: WebSocket

    func send<S: Collection>(_ message: S) async throws where S.Element == Character {
        try await websocket.send(message)
    }

    func error(_ message: String, code: Int) async throws {
        try await websocket.send("\(code): \(message)")
        try await websocket.close(code: .init(codeNumber: code))
    }

    func close() async throws {
        try await websocket.close()
    }
}
