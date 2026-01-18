import GraphQL
import GraphQLVapor
import Vapor

@main
struct HelloWorld {
    static func main() async throws {
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
        let graphQLHandler = GraphQLHandler(schema: schema)

        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = try await Application.make(env)
        app.get("graphql") { req in
            let context = GraphQLContext()
            return try await graphQLHandler.handle(req, context: context)
        }
        app.post("graphql") { req in
            let context = GraphQLContext()
            return try await graphQLHandler.handle(req, context: context)
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
