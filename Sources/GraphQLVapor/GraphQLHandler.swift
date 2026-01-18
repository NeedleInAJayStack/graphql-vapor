import GraphQL
import Vapor

/// A handler that processes GraphQL requests through Vapor
public struct GraphQLHandler: Sendable {
    public let schema: GraphQLSchema
    public let config: Config

    public struct Config: Sendable {
        public let allowGet: Bool
        public let additionalValidationRules: [@Sendable (ValidationContext) -> Visitor]

        public init(
            allowGet: Bool = true,
            additionalValidationRules: [@Sendable (ValidationContext) -> Visitor] = []
        ) {
            self.allowGet = allowGet
            self.additionalValidationRules = additionalValidationRules
        }
    }

    public init(
        schema: GraphQLSchema,
        config: Config = Config()
    ) {
        self.schema = schema
        self.config = config

        ContentConfiguration.global.use(encoder: GraphQLJSONEncoder(), for: .jsonGraphQL)
        ContentConfiguration.global.use(decoder: JSONDecoder(), for: .jsonGraphQL)
    }

    public func handle<Context: Sendable>(
        _ req: Request,
        context: Context
    ) async throws -> Response {

        // Support both GET and POST requests
        let graphQLRequest: GraphQLRequest
        let operationType: OperationType
        switch req.method {
            case .GET:
                guard config.allowGet else {
                    throw Abort(.methodNotAllowed, reason: "GET requests are disallowed")
                }

                // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#get
                graphQLRequest = try req.query.decode(GraphQLRequest.self)
                do {
                    operationType = try graphQLRequest.operationType()
                } catch {
                    // Indicates a request parsing error
                    throw Abort(.badRequest, reason: error.localizedDescription)
                }
                guard operationType != .mutation else {
                    throw Abort(.methodNotAllowed, reason: "Mutations using GET are disallowed")
                }
            case .POST:
                // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#post
                guard req.headers.contentType != nil else {
                    throw Abort(.unsupportedMediaType, reason: "Missing `Content-Type` header")
                }
                graphQLRequest = try req.content.decode(GraphQLRequest.self)
                do {
                    // Indicates a request parsing error
                    operationType = try graphQLRequest.operationType()
                } catch {
                    throw Abort(.badRequest, reason: error.localizedDescription)
                }
            default:
                throw Abort(.methodNotAllowed, reason: "Invalid method: \(req.method)")
        }

        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#validation
        let validationRules = GraphQL.specifiedRules + config.additionalValidationRules

        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#execution
        let result: GraphQLResult
        do {
            result = try await graphql(
                schema: schema,
                request: graphQLRequest.query,
                context: context,
                variableValues: graphQLRequest.variables,
                operationName: graphQLRequest.operationName,
                validationRules: validationRules
            )
        } catch {
            // This indicates a request parsing error
            throw Abort(.badRequest, reason: error.localizedDescription)
        }

        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#body
        let response = Response()
        var encoded = false
        for mediaType in req.headers.accept.mediaTypes {
            // Try to encode by the accepted headers, in order
            do {
                try response.content.encode(result, as: mediaType)
                encoded = true
                break
            } catch {
                continue
            }
        }
        if !encoded {
            // Use default if we haven't encoded yet
            try response.content.encode(result)
        }
        return response
    }
}
