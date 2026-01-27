import AsyncAlgorithms
import GraphQL
import GraphQLVapor
import Vapor

@main
struct HelloWorld {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = try await Application.make(env)

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "hello": GraphQLField(
                        type: GraphQLString,
                        resolve: { _, _, _, _ in
                            "World"
                        }
                    ),
                ]
            ),
            subscription: GraphQLObjectType(
                name: "Subscription",
                fields: [
                    "hello": GraphQLField(
                        type: GraphQLString,
                        description: "Emits an updated `World` message every 3 seconds",
                        resolve: { eventResult, _, _, _ in
                            eventResult
                        },
                        subscribe: { _, _, anyContext, _ in
                            let clock = ContinuousClock()
                            let start = clock.now
                            return AsyncTimerSequence(interval: .seconds(3), clock: ContinuousClock()).map { instant in
                                return "World at \(start.duration(to: instant))"
                            }
                        }
                    ),
                ]
            )
        )
        app.graphql(schema: schema, config: .init(subscriptionProtocols: [.websocket])) { _ in
            GraphQLContext()
        }

        do {
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    struct GraphQLContext: @unchecked Sendable { }
}
