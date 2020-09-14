//
//  API.swift
//  Mtel.me
//
//  Created by Predrag Samardzic on 25/08/2020.
//  Copyright © 2020 Wireless Media. All rights reserved.
//

import Foundation
import Combine
import Alamofire

public class API<T: OauthTokenProvider> {
    private let baseUrl: String
    private var headers: HTTPHeaders?
    private let printRequests: Bool
    private let interceptor: AccessTokenInterceptor<T>
    
    /// Init API client
    /// - Parameters:
    ///   - baseUrl: base API path. Paths from Endpoints will be appended to it
    ///   - commonHeaders: HTTP headers that should be added to each reqeust
    ///   - printRequests: Bool indicating if request data should be printed to console for debugging purposes
    ///   - oauthProvider: OauthTokenProvider, providing access and refresh tokens and ways to refresh token and logout user. Used to construct AccessTokenInterceptor
    public init(baseUrl: String,
         commonHeaders: [String: String]?,
         printRequests: Bool = true,
         oauthProvider: T) {
        
        self.baseUrl = baseUrl
        self.printRequests = printRequests
        interceptor = AccessTokenInterceptor(accessTokenProvider: oauthProvider)
        guard let commonHeaders = commonHeaders else {
            return
        }
        headers = HTTPHeaders(commonHeaders)
    }
    
    /// Make network request with decodable response
    /// Must be assignetd to publisher in order to infer types:
    /// - Response - Decodable type, used for decodint the response
    /// - DecodableError - Decodable type, used for decoding the error
    /// - Parameters:
    ///   - endpoint: Endpoint protocol implementation, containing information neccessary for constructing a request
    ///   - isAuthenticated: Bool indicating if it is needed to add Bearer token authentication to request headers and handle token refreshing
    /// - Returns: Publisher of decoded response and NetworkError
    public func request<Response: Decodable, Request: Endpoint, DecodableError: Decodable>(
        endpoint: Request,
        isAuthenticated: Bool = true) -> AnyPublisher<Response, NetworkError<DecodableError>> {
        
        let url = URL(string: baseUrl)!.appendingPathComponent(endpoint.path)
        let printRequest = self.printRequests
        
        return AF.request(url,
                   method: endpoint.httpMethod.alamofireMethod,
                   parameters: endpoint.parameters,
                   encoder: endpoint.encoding.encoder,
                   headers: headers,
                   interceptor: isAuthenticated ? interceptor : nil)
            .validate()
            .publishData()
            .tryMap({ (response) -> Data in
                try NetworkError<DecodableError>.processResponse(response, printRequest: printRequest)
            })
            .decode(type: Response.self, decoder: endpoint.decoder)
            .mapError({ error in
                error as? NetworkError ?? NetworkError<DecodableError>.parseError(error)
            })
            .eraseToAnyPublisher()
    }

    /// Make network request without decodable response
    /// Must be assigne to publisher in order to infer error type:
    /// - DecodableError - Decodable type, used for decoding the error
    /// - Parameters:
    ///   - endpoint: Endpoint protocol implementation, containing information neccessary for constructing a request
    ///   - isAuthenticated: Bool indicating if it is needed to add Bearer token authentication to request headers and handle token refreshing
    /// - Returns: Publisher
    public func request<Request: Endpoint, DecodableError: Decodable>(
        endpoint: Request,
        isAuthenticated: Bool = true) -> AnyPublisher<Void, NetworkError<DecodableError>> {
        
        let url = URL(string: baseUrl)!.appendingPathComponent(endpoint.path)
        let printRequest = self.printRequests
        
        return AF.request(url,
                   method: endpoint.httpMethod.alamofireMethod,
                   parameters: endpoint.parameters,
                   encoder: endpoint.encoding.encoder,
                   headers: headers,
                   interceptor: isAuthenticated ? interceptor : nil)
            .validate()
            .publishUnserialized()
            .tryMap({ (response) -> Void in
                try NetworkError<DecodableError>.processResponse(response, printRequest: printRequest)
            })
            .mapError({ error in
                error as? NetworkError ?? NetworkError<DecodableError>.parseError(error)
            })
            .eraseToAnyPublisher()
    }
}

//  MARK: - Types
public protocol Endpoint {
    associatedtype Parameters: Encodable
    var path: String { get }
    var parameters: Parameters? { get }
    var encoding: ParametersEncoding { get }
    var httpMethod: HTTPMethod { get }
    var decoder: JSONDecoder { get }
}

public enum ParametersEncoding {
    case query, urlEncoded, jsonEncoded
}

public enum HTTPMethod {
    case get, post, put, delete, patch
}

//  MARK: - Utility
extension ParametersEncoding {
    
    /// Maps our enum to Alamofire's ParameterEncoder
    var encoder: ParameterEncoder {
        let encoder: ParameterEncoder
        
        switch self {
        case .query:
            encoder = URLEncodedFormParameterEncoder(encoder: URLEncodedFormEncoder(),
                                                     destination: .queryString)
        case .urlEncoded:
            encoder = URLEncodedFormParameterEncoder.default
        case .jsonEncoded:
            encoder = JSONParameterEncoder.default
        }
        
        return encoder
    }
}

extension HTTPMethod {
    
    /// Maps our enum to Alamofire's HTTPMethod
    var alamofireMethod: Alamofire.HTTPMethod {
        switch self {
        case .post:
            return .post
        default:
            return .get
        }
    }
}
