import GraphQL
import GraphQLTransportWS
@testable import GraphQLVapor
import GraphQLWS
import Testing
import VaporTesting

@Suite
struct WebSocketTests {
    @Test func subscription() async throws {
        try await withApp { app in
            let pubsub = SimplePubSub<String>()
            let schema = try GraphQLSchema(
                subscription: GraphQLObjectType(
                    name: "Subscription",
                    fields: [
                        "hello": GraphQLField(
                            type: GraphQLString,
                            resolve: { source, _, _, _ in
                                source as! String
                            },
                            subscribe: { _, _, _, _ in
                                await pubsub.subscribe()
                            }
                        ),
                    ]
                )
            )

            app.graphql(schema: schema, config: .init(subscriptionProtocols: [.websocket])) { _ in
                EmptyContext()
            }

            app.http.server.configuration.port = 0
            app.environment.arguments = ["serve"]
            try await app.startup()
            let port = try #require(app.http.server.shared.localAddress?.port)
            try await WebSocket.connect(
                to: "ws://localhost:\(port)/graphql",
                headers: ["Connection": "Upgrade"],
                on: MultiThreadedEventLoopGroup(numberOfThreads: 1)
            ) { websocket in
                let decoder = JSONDecoder()
                websocket.onText { websocket, message in
                    do {
                        #expect(!message.starts(with: "44"))
                        let response = try #require(message.data(using: .utf8))
                        if let _ = try? decoder.decode(GraphQLTransportWS.ConnectionAckResponse.self, from: response) {
                            try await websocket.send(#"""
                            {
                                "type": "subscribe",
                                "payload": {
                                    "query": "subscription { hello }"
                                },
                                "id": "1"
                            }
                            """#)
                            // Must wait for a few milliseconds for the subscription to get set up.
                            try await Task.sleep(for: .milliseconds(10))
                            await pubsub.emit(event: "World")
                        } else if let next = try? decoder.decode(GraphQLTransportWS.NextResponse.self, from: response) {
                            #expect(next.payload?.errors == [])
                            #expect(next.payload?.data == ["hello": "World"])
                            await pubsub.cancel()
                        } else if let _ = try? decoder.decode(GraphQLTransportWS.CompleteResponse.self, from: response) {
                            try await websocket.close()
                        } else if let _ = try? decoder.decode(GraphQLTransportWS.ErrorResponse.self, from: response) {
                            Issue.record("Error message: \(message)")
                            await pubsub.cancel()
                            try await websocket.close()
                        } else {
                            Issue.record("Unrecognized message: \(message)")
                            return
                        }
                    } catch {
                        Issue.record("WebSocket error: \(error)")
                        return
                    }
                }
                do {
                    try await websocket.send(#"{"type": "connection_init", "payload": {}}"#)
                    try await websocket.onClose.get()
                } catch {
                    Issue.record("WebSocket error: \(error)")
                    return
                }
            }
        }
    }

    @Test func subscription_GraphQLWS() async throws {
        try await withApp { app in
            let pubsub = SimplePubSub<String>()
            let schema = try GraphQLSchema(
                subscription: GraphQLObjectType(
                    name: "Subscription",
                    fields: [
                        "hello": GraphQLField(
                            type: GraphQLString,
                            resolve: { source, _, _, _ in
                                source as! String
                            },
                            subscribe: { _, _, _, _ in
                                await pubsub.subscribe()
                            }
                        ),
                    ]
                )
            )

            app.graphql(schema: schema, config: .init(subscriptionProtocols: [.websocket])) { _ in
                EmptyContext()
            }

            app.http.server.configuration.port = 0
            app.environment.arguments = ["serve"]
            try await app.startup()
            let port = try #require(app.http.server.shared.localAddress?.port)
            try await WebSocket.connect(
                to: "ws://localhost:\(port)/graphql",
                headers: [
                    "Connection": "Upgrade",
                    "Sec-WebSocket-Protocol": "graphql-ws",
                ],
                on: MultiThreadedEventLoopGroup(numberOfThreads: 1)
            ) { websocket in
                let decoder = JSONDecoder()
                websocket.onText { websocket, message in
                    do {
                        #expect(!message.starts(with: "44"))
                        let response = try #require(message.data(using: .utf8))
                        if let _ = try? decoder.decode(GraphQLWS.ConnectionAckResponse.self, from: response) {
                            try await websocket.send(#"""
                            {
                                "type": "start",
                                "payload": {
                                    "query": "subscription { hello }"
                                },
                                "id": "1"
                            }
                            """#)
                            // Must wait for a few milliseconds for the subscription to get set up.
                            try await Task.sleep(for: .milliseconds(10))
                            await pubsub.emit(event: "World")
                        } else if let next = try? decoder.decode(GraphQLWS.DataResponse.self, from: response) {
                            #expect(next.payload?.errors == [])
                            #expect(next.payload?.data == ["hello": "World"])
                            await pubsub.cancel()
                        } else if let _ = try? decoder.decode(GraphQLWS.CompleteResponse.self, from: response) {
                            try await websocket.close()
                        } else if let _ = try? decoder.decode(GraphQLWS.ErrorResponse.self, from: response) {
                            Issue.record("Error message: \(message)")
                            await pubsub.cancel()
                            try await websocket.close()
                        } else {
                            Issue.record("Unrecognized message: \(message)")
                            return
                        }
                    } catch {
                        Issue.record("WebSocket error: \(error)")
                        return
                    }
                }
                do {
                    try await websocket.send(#"{"type": "connection_init", "payload": {}}"#)
                    try await websocket.onClose.get()
                } catch {
                    Issue.record("WebSocket error: \(error)")
                    return
                }
            }
        }
    }
}

/// A very simple publish/subscriber used for testing
actor SimplePubSub<T: Sendable>: Sendable {
    private var subscribers: [Subscriber<T>]

    init() {
        subscribers = []
    }

    func emit(event: T) {
        for subscriber in subscribers {
            subscriber.callback(event)
        }
    }

    func cancel() {
        for subscriber in subscribers {
            subscriber.cancel()
        }
    }

    func subscribe() -> AsyncThrowingStream<T, Error> {
        return AsyncThrowingStream<T, Error> { continuation in
            let subscriber = Subscriber<T>(
                callback: { newValue in
                    continuation.yield(newValue)
                },
                cancel: {
                    continuation.finish()
                }
            )
            subscribers.append(subscriber)
        }
    }
}

struct Subscriber<T> {
    let callback: (T) -> Void
    let cancel: () -> Void
}
