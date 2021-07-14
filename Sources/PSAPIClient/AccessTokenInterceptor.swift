//
//  AccessTokenInterceptor.swift
//  Mtel.me
//
//  Created by Predrag Samardzic on 05/09/2020.
//  Copyright © 2020 Wireless Media. All rights reserved.
//

import Alamofire
import Foundation
import Combine

public protocol TokenResponse: Decodable {
    var accessToken: String? { get }
    var refreshToken: String? { get }
}

public protocol OauthTokenProvider {
    associatedtype Response: TokenResponse
    associatedtype ErrorType: ErrorMessageParsable
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    var authPaths: [String] { get }
    var doNotRefreshPaths: [String] { get }
    func logout()
    func getNewToken(_ token: String) -> AnyPublisher<Response, NetworkError<ErrorType>>
}

public class AccessTokenInterceptor<T: OauthTokenProvider>: RequestInterceptor {
    //  MARK: - Properties
    private var accessTokenProvider: T
    private var isRefreshing = false
    private var requestsToRetry: [(RetryResult) -> Void] = []
    private let queue = DispatchQueue(label: "RefreshTokenQueue")
    private var cancellable: AnyCancellable?
    
    init(accessTokenProvider: T) {
        self.accessTokenProvider = accessTokenProvider
    }
    
    //  MARK: - Refresh logic
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let accessToken = accessTokenProvider.accessToken,
            !urlRequest.pathContains(anyOf: accessTokenProvider.authPaths)
            else { return completion(.success(urlRequest)) }
        
        var urlRequest = urlRequest
        urlRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        
        completion(.success(urlRequest))
    }
    
    public func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let response = request.task?.response as? HTTPURLResponse,
            response.statusCode == 401,
            request.task?.currentRequest?.pathContains(anyOf: accessTokenProvider.doNotRefreshPaths) != true
            else { return completion(.doNotRetryWithError(error)) }
        
        guard let currentRefreshToken = accessTokenProvider.refreshToken else {
            return doNotRetry(error: NSError(domain: "Authorization", code: 600))
        }
        
        queue.sync {
            requestsToRetry.append(completion)
            if !isRefreshing {
                isRefreshing = true
                cancellable = accessTokenProvider
                    .getNewToken(currentRefreshToken)
                    .sink(receiveCompletion: { [weak self](response) in
                        if case let .failure(error) = response {
                            self?.doNotRetry(error: error)
                            self?.accessTokenProvider.logout()
                        }
                    }) { [weak self](response) in
                        self?.updateTokens(response: response)
                }
            }
        }
    }
    
    //  MARK: - Utility
    private func updateTokens(response: TokenResponse) {
        accessTokenProvider.refreshToken = response.refreshToken
        accessTokenProvider.accessToken = response.accessToken
        requestsToRetry.forEach { $0(.retry) }
        onRefreshDone()
    }
    
    private func doNotRetry(error: Error) {
        accessTokenProvider.logout()
        requestsToRetry.forEach { $0(.doNotRetryWithError(error)) }
        onRefreshDone()
    }
    
    private func onRefreshDone() {
        requestsToRetry.removeAll()
        isRefreshing = false
    }
}

private extension URLRequest {
    func pathContains(anyOf subPaths: [String]) -> Bool {
        for subPath in subPaths {
            if url?.absoluteString.contains(subPath) == true {
                return true
            }
        }
        return false
    }
}
