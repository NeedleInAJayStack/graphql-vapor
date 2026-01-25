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
            )
        )
        app.graphql(schema: schema) { _ in
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

    struct GraphQLContext: Sendable {}
}
