//
//  NetworkError.swift
//  Mtel.me
//
//  Created by Predrag Samardzic on 25/08/2020.
//  Copyright © 2020 Wireless Media. All rights reserved.
//

import Foundation
import Alamofire

public protocol ErrorMessageParsable where Self: Decodable {
    var message: String? { get }
    static var decoder: JSONDecoder { get }
}

public enum NetworkError<T: ErrorMessageParsable>: Error {
    case noNet
    case unauthorized
    case message(_ message: String)
    case parseError(_ error: Error)
    case unknown(error: Error?, data: Data?)
    
    static func processResponse(_ response: DataResponse<Data, AFError>, printRequest: Bool) throws -> Data {
        
        if printRequest {
            printResponse(response)
        }
        
        switch response.result {
        case let .success(data):
            return data
            
        case let .failure(error):
            guard let statusCode = response.response?.statusCode, let data = response.data else {
                throw unknown(error: error, data: response.data)
            }
            
            switch statusCode {
            case URLError.Code.notConnectedToInternet.rawValue:
                throw noNet
            case 401:
                throw unauthorized
            default:
                do {
                    
                    let decodedError = try T.decoder.decode(T.self, from: data)
                    if let msg = decodedError.message {
                        throw message(msg)
                    } else {
                        throw unknown(error: error, data: data)
                    }
                } catch let error {
                    throw unknown(error: error, data: data)
                }
            }
        }
    }
    
    static func processResponse(_ response: DataResponse<Data?, AFError>, printRequest: Bool) throws -> Void {
        
        if printRequest {
            printResponse(response)
        }
        
        switch response.result {
        case .success:
            return ()
            
        case let .failure(error):
            guard let statusCode = response.response?.statusCode, let data = response.data else {
                throw unknown(error: error, data: response.data)
            }
            
            switch statusCode {
            case URLError.Code.notConnectedToInternet.rawValue:
                throw noNet
            case 401:
                throw unauthorized
            default:
                do {
                    
                    let decodedError = try T.decoder.decode(T.self, from: data)
                    if let msg = decodedError.message {
                        throw message(msg)
                    } else {
                        throw unknown(error: error, data: data)
                    }
                } catch let error {
                    throw unknown(error: error, data: data)
                }
            }
        }
    }
    
    private static func printResponse(_ response: AFDataResponse<Data>?) {
        guard let response = response else { return }
        printResponse(response)
    }
    
    private static func printResponse(_ response: AFDataResponse<Data?>?) {
        guard let response = response else { return }
        printResponse(response)
    }
    
    private static func printResponse(_ response: AFDataResponse<Data>) {
        print("\nRequest headers: \(response.request?.allHTTPHeaderFields ?? ["": "- Empty -"])")
        print("Request: 🔗 \(response.request?.httpMethod ?? "") \(response.request?.url?.absoluteString ?? "- Empty -") 🔗")
        if let data = response.data, let datastring = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            print("Response body: 📦 StatusCode: \(response.response?.statusCode ?? -1) 📦 \(datastring) 📦\n")
        }
        else {
            print("Response body: 📦 StatusCode: \(response.response?.statusCode ?? -1) 📦  - Empty -  📦\n")
        }
    }
}
