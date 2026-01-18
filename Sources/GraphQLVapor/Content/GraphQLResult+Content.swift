import GraphQL
import Vapor

extension GraphQLResult: @retroactive Content {
    public static let defaultContentType: HTTPMediaType = .jsonGraphQL
}
