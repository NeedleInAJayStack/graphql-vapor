import Vapor

public extension HTTPMediaType {
    static let jsonGraphQL = HTTPMediaType(type: "application", subType: "graphql-response+json", parameters: ["charset": "utf-8"])
}
