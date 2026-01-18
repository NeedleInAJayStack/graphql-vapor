import GraphQL
import Vapor

extension GraphQLJSONEncoder: @retroactive ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout NIOCore.ByteBuffer, headers: inout NIOHTTP1.HTTPHeaders) throws where E : Encodable {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }

    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders, userInfo: [CodingUserInfoKey: Sendable]) throws
        where E: Encodable
    {
        headers.contentType = .jsonGraphQL

        if !userInfo.isEmpty { // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            let encoder = GraphQLJSONEncoder.custom(
                dates: self.dateEncodingStrategy,
                data: self.dataEncodingStrategy,
                keys: self.keyEncodingStrategy,
                format: self.outputFormatting,
                floats: self.nonConformingFloatEncodingStrategy
            ) // don't use userInfo parameter of `JSONEncoder.custom()` until Swift 6.2 is required
            encoder.userInfo = self.userInfo.merging(userInfo) { $1 }
            try body.writeBytes(encoder.encode(encodable))
        } else {
            try body.writeBytes(self.encode(encodable))
        }
    }
}

extension GraphQLJSONEncoder {
    /// Convenience for creating a customized ``Foundation/GraphQLJSONEncoder``.
    ///
    ///     let encoder: GraphQLJSONEncoder = .custom(dates: .millisecondsSince1970)
    ///
    /// - Parameters:
    ///   - dates: Date encoding strategy.
    ///   - data: Data encoding strategy.
    ///   - keys: Key encoding strategy.
    ///   - format: Output formatting.
    ///   - floats: Non-conforming float encoding strategy.
    ///   - userInfo: Coder userInfo.
    /// - Returns: Newly created ``Foundation/JSONEncoder``.
    public static func custom(
        dates dateStrategy: GraphQLJSONEncoder.DateEncodingStrategy? = nil,
        data dataStrategy: GraphQLJSONEncoder.DataEncodingStrategy? = nil,
        keys keyStrategy: GraphQLJSONEncoder.KeyEncodingStrategy? = nil,
        format outputFormatting: GraphQLJSONEncoder.OutputFormatting? = nil,
        floats floatStrategy: GraphQLJSONEncoder.NonConformingFloatEncodingStrategy? = nil,
        userInfo: [CodingUserInfoKey: Sendable]? = nil
    ) -> GraphQLJSONEncoder {
        let json = GraphQLJSONEncoder()
        if let dateStrategy = dateStrategy {
            json.dateEncodingStrategy = dateStrategy
        }
        if let dataStrategy = dataStrategy {
            json.dataEncodingStrategy = dataStrategy
        }
         if let keyStrategy = keyStrategy {
             json.keyEncodingStrategy = keyStrategy
         }
        if let outputFormatting = outputFormatting {
            json.outputFormatting = outputFormatting
        }
        if let floatStrategy = floatStrategy {
            json.nonConformingFloatEncodingStrategy = floatStrategy
        }
        if let userInfo = userInfo {
            json.userInfo = userInfo
        }
        return json
    }
}
