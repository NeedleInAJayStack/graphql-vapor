import GraphQL
import struct GraphQLTransportWS.EmptyInitPayload
import class GraphQLTransportWS.Server
import class GraphQLWS.Server
import Vapor

extension GraphQLHandler {
    func handleWebSocket(
        request: Request
    ) async throws -> Response {
        let subProtocol = try negotiateSubProtocol(request: request)
        let graphQLContextComputationInputs = GraphQLContextComputationInputs(
            vaporRequest: request
        )
        let context = try await computeContext(graphQLContextComputationInputs)
        let response = Response(status: .switchingProtocols)
        response.upgrader = WebSocketUpgrader(
            maxFrameSize: .default,
            shouldUpgrade: {
                request.eventLoop.makeFutureWithTask {
                    ["Sec-WebSocket-Protocol": subProtocol.rawValue]
                }
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
                                rootValue: rootValue,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            )
                        },
                        onSubscribe: { graphQLRequest in
                            try await graphqlSubscribe(
                                schema: schema,
                                request: graphQLRequest.query,
                                rootValue: rootValue,
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
                                rootValue: rootValue,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            )
                        },
                        onSubscribe: { graphQLRequest in
                            try await graphqlSubscribe(
                                schema: schema,
                                request: graphQLRequest.query,
                                rootValue: rootValue,
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
        return response
    }

    func negotiateSubProtocol(request: Request) throws -> WebSocketSubProtocol {
        var subProtocol: WebSocketSubProtocol?
        let requestedSubProtocols = request.headers["Sec-WebSocket-Protocol"]
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
        return subProtocol
    }
}
