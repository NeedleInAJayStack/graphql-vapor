import GraphQL
import Vapor

struct GraphQLHandler<
    Context: Sendable,
    WebSocketInit: Equatable & Codable & Sendable,
    WebSocketInitResult: Sendable
>: Sendable {
    let schema: GraphQLSchema
    let rootValue: any Sendable
    let config: GraphQLConfig<WebSocketInit, WebSocketInitResult>
    let computeContext: @Sendable (GraphQLContextComputationInputs<WebSocketInitResult>) async throws -> Context
}
