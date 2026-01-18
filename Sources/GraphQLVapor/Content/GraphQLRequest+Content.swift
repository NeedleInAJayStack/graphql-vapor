import GraphQL
import Vapor

extension GraphQLRequest: @retroactive Content {
    public static let defaultContentType: HTTPMediaType = .json
}
