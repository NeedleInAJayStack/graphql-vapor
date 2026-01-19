import GraphQLTransportWS
import GraphQLWS
import WebSocketKit

/// Messenger wrapper for WebSockets
class WebSocketMessenger: GraphQLTransportWS.Messenger, GraphQLWS.Messenger {
    private weak var websocket: WebSocket?
    private var onReceive: (String) async throws -> Void = { _ in }

    init(websocket: WebSocket) {
        self.websocket = websocket
        websocket.onText { _, message in
            // We must include self here, without a weak reference to prevent it from falling
            // out of scope while the websocket is still alive
            do {
                try await self.onReceive(message)
            }
            catch {
                try? await self.error("\(error)", code: 4400)
            }
        }
        websocket.onClose.whenComplete { [weak self] _ in
            guard let self = self else {
                return
            }
            self.onReceive { _ in }
            websocket.onText { _, _ in }
        }
    }

    func send<S>(_ message: S) async throws where S: Collection, S.Element == Character {
        guard let websocket = websocket else { return }
        try await websocket.send(message)
    }

    func onReceive(callback: @escaping (String) async throws -> Void) {
        self.onReceive = callback
    }

    func error(_ message: String, code: Int) async throws {
        guard let websocket = websocket else { return }
        try await websocket.send("\(code): \(message)")
        try await websocket.close(code: .init(codeNumber: code))
    }

    func close() async throws {
        guard let websocket = websocket else { return }
        try await websocket.close()
    }
}
