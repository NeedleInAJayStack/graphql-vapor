import GraphQL
import Vapor

struct GraphQLHandler<
    Context: Sendable,
    WebSocketInit: Equatable & Codable & Sendable
>: Sendable {
    let schema: GraphQLSchema
    let config: GraphQLConfig<WebSocketInit>
    let computeContext: @Sendable (Request) async throws -> Context

    init(
        schema: GraphQLSchema,
        config: GraphQLConfig<WebSocketInit>,
        computeContext: @Sendable @escaping (Request) async throws -> Context
    ) {
        self.schema = schema
        self.config = config
        self.computeContext = computeContext
    }

    // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#get
    func handleGet(request: Request) async throws -> Response {
        let graphQLRequest = try request.query.decode(GraphQLRequest.self)
        let operationType: OperationType
        do {
            operationType = try graphQLRequest.operationType()
        } catch {
            // Indicates a request parsing error
            throw Abort(.badRequest, reason: error.localizedDescription)
        }
        guard operationType != .mutation else {
            throw Abort(.methodNotAllowed, reason: "Mutations using GET are disallowed")
        }
        let context = try await computeContext(request)
        let result = try await execute(
            graphQLRequest: graphQLRequest,
            context: context,
            additionalValidationRules: config.additionalValidationRules
        )
        return try encodeResponse(result: result, headers: request.headers)
    }

    // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#post
    func handlePost(request: Request) async throws -> Response {
        guard request.headers.contentType != nil else {
            throw Abort(.unsupportedMediaType, reason: "Missing `Content-Type` header")
        }
        let graphQLRequest = try request.content.decode(GraphQLRequest.self)
        let context = try await computeContext(request)
        let result = try await execute(
            graphQLRequest: graphQLRequest,
            context: context,
            additionalValidationRules: config.additionalValidationRules
        )
        return try encodeResponse(result: result, headers: request.headers)
    }

    private func execute(
        graphQLRequest: GraphQLRequest,
        context: Context,
        additionalValidationRules: [@Sendable (ValidationContext) -> Visitor]
    ) async throws -> GraphQLResult {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#validation
        let validationRules = GraphQL.specifiedRules + additionalValidationRules

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
        return result
    }

    // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#body
    private func encodeResponse(result: GraphQLResult, headers: HTTPHeaders) throws -> Response {
        let response = Response()
        var encoded = false
        for mediaType in headers.accept.mediaTypes {
            // Try to respond in the best media type, in order
            do {
                try response.content.encode(result, as: mediaType)
                encoded = true
                break
            } catch {
                continue
            }
        }
        if !encoded {
            if config.allowMissingAcceptHeader {
                // Use default of `application/graphql-response+json`
                try response.content.encode(result)
            } else {
                throw Abort(.notAcceptable, reason: "An `Accept` header must be provided")
            }
        }
        return response
    }
}
