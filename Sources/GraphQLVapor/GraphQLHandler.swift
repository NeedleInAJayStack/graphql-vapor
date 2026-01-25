import GraphQL
import Vapor

struct GraphQLHandler<
    Context: Sendable,
    WebSocketInit: Equatable & Codable & Sendable
>: Sendable {
    let schema: GraphQLSchema
    let config: GraphQLConfig<WebSocketInit>

    init(
        schema: GraphQLSchema,
        config: GraphQLConfig<WebSocketInit>
    ) {
        self.schema = schema
        self.config = config

        ContentConfiguration.global.use(encoder: GraphQLJSONEncoder(), for: .jsonGraphQL)
        ContentConfiguration.global.use(decoder: JSONDecoder(), for: .jsonGraphQL)
    }

    func handle(
        _ req: Request,
        context: Context
    ) async throws -> Response {
        // Support both GET and POST requests
        let graphQLRequest: GraphQLRequest
        let operationType: OperationType
        switch req.method {
        case .GET:
            // WebSocket handling
            if req.headers.connection?.value.lowercased() == "upgrade" {
                return try await handleWebSocket(req, context: context)
            }

            // Get requests without a `query` parameter are considered to be IDE requests
            if req.url.query == nil || !(req.url.query?.contains("query") ?? true) {
                switch config.ide.type {
                case .graphiql:
                    return try await GraphiQLHandler.respond(url: req.url.string, subscriptionUrl: req.url.string)
                case .none:
                    // Let this get caught by the graphQLRequest decoding
                    break
                }
            }

            // Normal GET request handling
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
                operationType = try graphQLRequest.operationType()
            } catch {
                // Indicates a request parsing error
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
