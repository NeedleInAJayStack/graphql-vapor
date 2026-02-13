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
        let response = Response(status: .switchingProtocols)
        response.upgrader = WebSocketUpgrader(
            maxFrameSize: .default,
            shouldUpgrade: {
                request.eventLoop.makeFutureWithTask {
                    ["Sec-WebSocket-Protocol": subProtocol.rawValue]
                }
            },
            onUpgrade: { websocket in
                let messageStream = AsyncThrowingStream<String, Error> { continuation in
                    websocket.onText { _, text in
                        continuation.yield(text)
                    }
                    websocket.onClose.whenComplete { result in
                        switch result {
                        case .success:
                            continuation.finish()
                        case let .failure(error):
                            continuation.finish(throwing: error)
                        }
                    }
                }

                let messenger = WebSocketMessenger(websocket: websocket)
                switch subProtocol {
                case .graphqlTransportWs:
                    // https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md
                    let server = GraphQLTransportWS.Server<WebSocketInit, WebSocketInitResult, AsyncThrowingStream<GraphQLResult, Error>>(
                        messenger: messenger,
                        onInit: { initPayload in
                            try await config.websocket.onWebsocketInit(initPayload)
                        },
                        onExecute: { graphQLRequest, _ in
                            let graphQLContextComputationInputs = GraphQLContextComputationInputs(
                                vaporRequest: request,
                                graphQLRequest: graphQLRequest
                            )
                            let context = try await computeContext(graphQLContextComputationInputs)
                            return try await graphql(
                                schema: schema,
                                request: graphQLRequest.query,
                                rootValue: rootValue,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            )
                        },
                        onSubscribe: { graphQLRequest, _ in
                            let graphQLContextComputationInputs = GraphQLContextComputationInputs(
                                vaporRequest: request,
                                graphQLRequest: graphQLRequest
                            )
                            let context = try await computeContext(graphQLContextComputationInputs)
                            return try await graphqlSubscribe(
                                schema: schema,
                                request: graphQLRequest.query,
                                rootValue: rootValue,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            ).get()
                        }
                    )
                    Task {
                        // This task completes upon websocket closure
                        try await server.listen(to: messageStream)
                    }
                case .graphqlWs:
                    // https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md
                    let server = GraphQLWS.Server<WebSocketInit, WebSocketInitResult, AsyncThrowingStream<GraphQLResult, Error>>(
                        messenger: messenger,
                        onInit: { initPayload in
                            try await config.websocket.onWebsocketInit(initPayload)
                        },
                        onExecute: { graphQLRequest, _ in
                            let graphQLContextComputationInputs = GraphQLContextComputationInputs(
                                vaporRequest: request,
                                graphQLRequest: graphQLRequest
                            )
                            let context = try await computeContext(graphQLContextComputationInputs)
                            return try await graphql(
                                schema: schema,
                                request: graphQLRequest.query,
                                rootValue: rootValue,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            )
                        },
                        onSubscribe: { graphQLRequest, _ in
                            let graphQLContextComputationInputs = GraphQLContextComputationInputs(
                                vaporRequest: request,
                                graphQLRequest: graphQLRequest
                            )
                            let context = try await computeContext(graphQLContextComputationInputs)
                            return try await graphqlSubscribe(
                                schema: schema,
                                request: graphQLRequest.query,
                                rootValue: rootValue,
                                context: context,
                                variableValues: graphQLRequest.variables,
                                operationName: graphQLRequest.operationName
                            ).get()
                        }
                    )
                    Task {
                        // This task completes upon websocket closure
                        try await server.listen(to: messageStream)
                    }
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
