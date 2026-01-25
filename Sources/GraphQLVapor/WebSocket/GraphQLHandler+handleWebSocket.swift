import GraphQL
import struct GraphQLTransportWS.EmptyInitPayload
import class GraphQLTransportWS.Server
import class GraphQLWS.Server
import Vapor

extension GraphQLHandler {
    func handleWebSocket(
        _ req: Request,
        context: Context
    ) async throws -> Response {
        let res = Response(status: .switchingProtocols)
        var subProtocol: WebSocketSubProtocol?
        let requestedSubProtocols = req.headers["Sec-WebSocket-Protocol"]
        if requestedSubProtocols.isEmpty {
            // Default
            subProtocol = .graphqlTransportWs
        } else {
            // Choose highest client preference that we understand
            for requestedSubProtocol in requestedSubProtocols {
                if let selectedSubProtocol = WebSocketSubProtocol(rawValue: requestedSubProtocol) {
                    subProtocol = selectedSubProtocol
                    break
                }
            }
        }
        guard let subProtocol = subProtocol else {
            // If they provided options but none matched, fail
            throw Abort(.badRequest, reason: "Unable to negotiate subprotocol. \(WebSocketSubProtocol.allCases) are supported.")
        }
        res.headers.add(name: "Sec-WebSocket-Protocol", value: subProtocol.rawValue)

        res.upgrader = WebSocketUpgrader(
            maxFrameSize: .default,
            shouldUpgrade: {
                req.eventLoop.makeSucceededFuture([:])
            },
            onUpgrade: { websocket in
                let messenger = WebSocketMessenger(websocket: websocket)
                switch subProtocol {
                case .graphqlTransportWs:
                    // https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md
                    let server = GraphQLTransportWS.Server<WebSocketInit, AsyncThrowingStream<GraphQLResult, Error>>(
                        messenger: messenger,
                        onExecute: { graphQLRequest in
                            try await graphql(
                                schema: schema,
                                request: graphQLRequest.query,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            )
                        },
                        onSubscribe: { graphQLRequest in
                            try await graphqlSubscribe(
                                schema: schema,
                                request: graphQLRequest.query,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            ).get()
                        }
                    )
                    server.auth(config.websocket.onWebsocketInit)
                case .graphqlWs:
                    // https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md
                    let server = GraphQLWS.Server<WebSocketInit, AsyncThrowingStream<GraphQLResult, Error>>(
                        messenger: messenger,
                        onExecute: { graphQLRequest in
                            try await graphql(
                                schema: schema,
                                request: graphQLRequest.query,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            )
                        },
                        onSubscribe: { graphQLRequest in
                            try await graphqlSubscribe(
                                schema: schema,
                                request: graphQLRequest.query,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            ).get()
                        }
                    )
                    server.auth(config.websocket.onWebsocketInit)
                }
            }
        )
        return res
    }
}
