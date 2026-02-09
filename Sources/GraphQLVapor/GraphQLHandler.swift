import GraphQL
import Vapor

struct GraphQLHandler<
    Context: Sendable,
    WebSocketInit: Equatable & Codable & Sendable
>: Sendable {
    let schema: GraphQLSchema
    let rootValue: any Sendable
    let config: GraphQLConfig<WebSocketInit>
    let computeContext: @Sendable (GraphQLContextComputationInputs) async throws -> Context
}
