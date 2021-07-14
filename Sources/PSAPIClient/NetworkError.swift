//
//  NetworkError.swift
//  Mtel.me
//
//  Created by Predrag Samardzic on 25/08/2020.
//  Copyright © 2020 Wireless Media. All rights reserved.
//

import Foundation
import Alamofire

public protocol ErrorMessageParsable: Decodable {
    var message: String? { get }
    var code: String? { get }
    static var decoder: JSONDecoder { get }
}

public enum NetworkError<T: ErrorMessageParsable>: Error {
    
    case noNet
    case unauthorized
    case message(_ message: String, code: String?)
    case unknown(_ error: Error)
    
    static func processResponse(_ response: DataResponse<Data, AFError>, printRequest: Bool) throws -> Data {
        
        if printRequest {
            printResponse(response.response,
                          request: response.request,
                          data: response.data)
        }
        
        switch response.result {
        case let .success(data):
            return data
            
        case let .failure(error):
            throw processError(error,
                               statusCode: response.response?.statusCode,
                               data: response.data)
        }
    }
    
    static func processResponse(_ response: DataResponse<Data?, AFError>, printRequest: Bool) throws -> Void {
        
        if printRequest {
            printResponse(response.response,
                          request: response.request,
                          data: response.data)
        }
        
        switch response.result {
        case .success:
            return ()
            
        case let .failure(error):
            throw processError(error,
                               statusCode: response.response?.statusCode,
                               data: response.data)
        }
    }
    
    private static func processError(_ error: Error, statusCode: Int?, data: Data?) -> NetworkError {
        guard let statusCode = statusCode, let unwrappedData = data else {
            return unknown(error)
        }
        
        switch statusCode {
        case URLError.Code.notConnectedToInternet.rawValue:
            return noNet
        case 401:
            return unauthorized
        default:
            guard let decodedError = try? T.decoder.decode(T.self, from: unwrappedData), let msg = decodedError.message else {
                return unknown(error)
            }
            return message(msg, code: decodedError.code)
        }
    }
    
    private static func printResponse(_ response: HTTPURLResponse?,
                                      request: URLRequest?,
                                      data: Data?) {
        
        print("\nRequest headers: \(request?.allHTTPHeaderFields ?? ["": "- Empty -"])")
        
        if let httpBody = request?.httpBody, let datastring = NSString(data: httpBody, encoding: String.Encoding.utf8.rawValue) {
            print("Request body: \(datastring)")
        }
        
        print("Request: 🔗 \(request?.httpMethod ?? "") \(request?.url?.absoluteString ?? "- Empty -") 🔗")
        
        if let data = data, let datastring = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            print("Response body: 📦 StatusCode: \(response?.statusCode ?? -1) 📦 \(datastring) 📦\n")
        }
        else {
            print("Response body: 📦 StatusCode: \(response?.statusCode ?? -1) 📦  - Empty -  📦\n")
        }
    }
}
