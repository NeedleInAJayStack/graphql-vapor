import GraphQL
import Vapor

extension GraphQLHandler {
    /// https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#get
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
        let graphQLContextComputationInputs = GraphQLContextComputationInputs(
            vaporRequest: request
        )
        let context = try await computeContext(graphQLContextComputationInputs)
        let result = await execute(
            graphQLRequest: graphQLRequest,
            context: context,
            additionalValidationRules: config.additionalValidationRules
        )
        return try encodeResponse(result: result, headers: request.headers)
    }

    /// https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#post
    func handlePost(request: Request) async throws -> Response {
        guard request.headers.contentType != nil else {
            throw Abort(.unsupportedMediaType, reason: "Missing `Content-Type` header")
        }
        let graphQLRequest = try request.content.decode(GraphQLRequest.self)
        let graphQLContextComputationInputs = GraphQLContextComputationInputs(
            vaporRequest: request
        )
        let context = try await computeContext(graphQLContextComputationInputs)
        let result = await execute(
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
    ) async -> GraphQLResult {
        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#validation
        let validationRules = GraphQL.specifiedRules + additionalValidationRules

        // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#execution
        let result: GraphQLResult
        do {
            result = try await graphql(
                schema: schema,
                request: graphQLRequest.query,
                rootValue: rootValue,
                context: context,
                variableValues: graphQLRequest.variables,
                operationName: graphQLRequest.operationName,
                validationRules: validationRules
            )
        } catch let error as GraphQLError {
            // This indicates a request parsing error
            return GraphQLResult(data: nil, errors: [error])
        } catch {
            return GraphQLResult(data: nil, errors: [GraphQLError(message: error.localizedDescription)])
        }
        return result
    }

    /// https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#body
    private func encodeResponse(result: GraphQLResult, headers: HTTPHeaders) throws -> Response {
        if !config.allowMissingAcceptHeader, headers.accept.isEmpty {
            throw Abort(.notAcceptable, reason: "An `Accept` header must be provided")
        }

        let response = Response()

        let configuredMediaTypes: Set<HTTPMediaType> = [.jsonGraphQL, .json]

        // Try to respond with the best matching media type, in order
        var selectedMediaType: HTTPMediaType? = nil
        for mediaType in headers.accept.mediaTypes {
            if configuredMediaTypes.contains(mediaType) {
                selectedMediaType = mediaType
                break
            }
        }

        // If no exact matches, look for any matching wildcards
        if selectedMediaType == nil {
            let acceptableMediaSet = HTTPMediaTypeSet(mediaTypes: headers.accept.mediaTypes)
            for mediaType in configuredMediaTypes {
                if acceptableMediaSet.contains(mediaType) {
                    selectedMediaType = mediaType
                    break
                }
            }
        }

        // Use the default if configured to do so
        if selectedMediaType == nil, config.allowMissingAcceptHeader {
            selectedMediaType = .jsonGraphQL
        }

        guard let selectedMediaType else {
            // Fail
            throw Abort(.notAcceptable)
        }

        if selectedMediaType == .jsonGraphQL, result.data == nil {
            // We must return `bad request` with the content if there were failures preventing a partial result
            // https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md#applicationgraphql-responsejson
            response.status = .badRequest
        }

        try response.content.encode(result, as: selectedMediaType)
        return response
    }
}
