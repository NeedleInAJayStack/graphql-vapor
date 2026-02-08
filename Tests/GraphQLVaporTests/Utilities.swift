import GraphQL
import Vapor

let jsonGraphQLHeaders: HTTPHeaders = [
    "Accept": HTTPMediaType.jsonGraphQL.serialize(),
    "Content-Type": HTTPMediaType.jsonGraphQL.serialize(),
]

let jsonHeaders: HTTPHeaders = [
    "Accept": HTTPMediaType.json.serialize(),
    "Content-Type": HTTPMediaType.json.serialize(),
]

let helloWorldSchema = try! GraphQLSchema(
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

struct EmptyContext: Sendable {}
