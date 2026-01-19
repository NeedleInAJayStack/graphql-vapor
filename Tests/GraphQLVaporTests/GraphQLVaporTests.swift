import Testing
import VaporTesting
import GraphQL
import GraphQLTransportWS
import GraphQLWS
@testable import GraphQLVapor

@Suite("GraphQLVapor Tests")
struct GraphQLVaporTests {
    @Test func basicQuery() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "hello": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, _, _ in
                                "World"
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(GraphQLRequest(query: "{ hello }"))
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["hello"] == "World")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func queryWithVariables() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "greet": GraphQLField(
                            type: GraphQLString,
                            args: [
                                "name": GraphQLArgument(type: GraphQLString)
                            ],
                            resolve: { _, args, _, _ in
                                guard let name = args["name"].string else {
                                    return "Hello, stranger"
                                }
                                return "Hello, \(name)"
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(
                    GraphQLRequest(
                        query: "query Greet($name: String) { greet(name: $name) }",
                        variables: ["name": "Alice"]
                    )
                )
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["greet"] == "Hello, Alice")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func queryWithContext() async throws {
        try await withApp { app in
            struct Context: Sendable {
                let message: String
            }

            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "contextMessage": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, context, _ in
                                guard let ctx = context as? Context else {
                                    throw GraphQLError(message: "Invalid context")
                                }
                                return ctx.message
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: Context(message: "Hello from context!"))
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(GraphQLRequest(query: "{ contextMessage }"))
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["contextMessage"] == "Hello from context!")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func jsonContent() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "hello": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, _, _ in
                                "World"
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                req.headers.replaceOrAdd(name: .accept, value: HTTPMediaType.json.serialize())
                try req.content.encode(GraphQLRequest(query: "{ hello }"), as: .json)
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .json)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["hello"] == "World")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func errorHandling() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "error": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, _, _ in
                                throw GraphQLError(message: "Something went wrong")
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.post("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.POST, "/graphql") { req in
                try req.content.encode(GraphQLRequest(query: "{ error }"))
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.headers.contentType == .jsonGraphQL)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(!response.errors.isEmpty)
                #expect(response.errors.first?.message == "Something went wrong")
            }
        }
    }

    @Test func getRequest() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "test": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, _, _ in
                                "GET works"
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.get("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.GET, "/graphql?query=%7Btest%7D") { _ in
            } afterResponse: { res in
                #expect(res.status == .ok)

                let response = try res.content.decode(GraphQLResult.self)
                #expect(response.data?["test"] == "GET works")
                #expect(response.errors.isEmpty)
            }
        }
    }

    @Test func graphiql() async throws {
        try await withApp { app in
            let schema = try GraphQLSchema(
                query: GraphQLObjectType(
                    name: "Query",
                    fields: [
                        "hello": GraphQLField(
                            type: GraphQLString,
                            resolve: { _, _, _, _ in
                                "World"
                            }
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.get("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            try await app.test(.GET, "/graphql") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == GraphiQLHandler.html(url: "/graphql"))
            }
        }
    }

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
                                return source as! String
                            },
                            subscribe: { _, _, context, _ in
                                return await pubsub.subscribe()
                            },
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.get("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            app.http.server.configuration.port = 0
            app.environment.arguments = ["serve"]
            try await app.startup()
            let port = try #require(app.http.server.shared.localAddress?.port)
            try await WebSocket.connect(
                to: "ws://localhost:\(port)/graphql",
                headers: ["Connection": "Upgrade"],
                on: MultiThreadedEventLoopGroup(numberOfThreads: 1),
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
                            """#
                            )
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
                                return source as! String
                            },
                            subscribe: { _, _, context, _ in
                                return await pubsub.subscribe()
                            },
                        )
                    ]
                )
            )

            let handler = GraphQLHandler(schema: schema)
            app.get("graphql") { request in
                try await handler.handle(request, context: EmptyContext())
            }

            app.http.server.configuration.port = 0
            app.environment.arguments = ["serve"]
            try await app.startup()
            let port = try #require(app.http.server.shared.localAddress?.port)
            try await WebSocket.connect(
                to: "ws://localhost:\(port)/graphql",
                headers: [
                    "Connection": "Upgrade",
                    "Sec-WebSocket-Protocol": "graphql-ws"
                ],
                on: MultiThreadedEventLoopGroup(numberOfThreads: 1),
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
                            """#
                            )
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

    struct EmptyContext: Sendable {}
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
