//
//  NetworkingMock.swift
//  Core
//
//  Created by Igor Kulman on 25.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking
import ProtonCore_Services
import ProtonCore_Authentication
@testable import vpncore

final class NetworkingMock {
    var apiURLString = ""

    var apiService: PMAPIService {
        fatalError()
    }

    var requestCallback: ((URLRequest) -> Result<Data, Error>)?

    func request(_ route: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        if let requestCallback = requestCallback {
            completion(requestCallback(route))
        }
    }

    func request(_ route: Request, completion: @escaping (Result<Data, Error>) -> Void) {
        var urlRequest = Foundation.URLRequest(url: URL(string: "\(apiURLString)\(route.path)")!)
        urlRequest.httpMethod = route.method.toString()

        for (header, value) in route.header {
            urlRequest.setValue(value as? String, forHTTPHeaderField: header)
        }

        if let parameters = route.parameters {
            do {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                completion(.failure(error))
            }
        }

        request(urlRequest, completion: completion)
    }
}

extension NetworkingMock: Networking {
    func request(_ route: Request, completion: @escaping (Result<JSONDictionary, Error>) -> Void) {
        request(route) { (result: Result<Data, Error>) in
            switch result {
            case let .success(data):
                guard let dict = data.jsonDictionary else {
                    completion(.failure(POSIXError(.EBADMSG)))
                    return
                }

                completion(.success(dict))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func request(_ route: Request, completion: @escaping (Result<(), Error>) -> Void) {
        request(route) { (result: Result<Data, Error>) in
            switch result {
            case .success:
                completion(.success(()))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func request(_ route: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {
        request(route) { (result: Result<Data, Error>) in
            switch result {
            case let .success(data):
                guard let str = String(data: data, encoding: .utf8) else {
                    completion(.failure(POSIXError(.EBADMSG)))
                    return
                }
                completion(.success(str))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func request<T>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
        request(route) { (result: Result<Data, Error>) in
            switch result {
            case let .success(data):
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                    let obj = try decoder.decode(T.self, from: data)
                    completion(.success(obj))
                } catch {
                    completion(.failure(error))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    // the files argument is ignored for now...
    func request<T>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
        request(route, completion: completion)
    }
}

extension NetworkingMock: APIServiceDelegate {
    public var additionalHeaders: [String: String]? {
        return nil
    }
    public var locale: String {
        return NSLocale.current.languageCode ?? "en_US"
    }
    public var appVersion: String {
        return "UNIT TESTS APP VERSION"
    }
    public var userAgent: String? {
        return "UNIT TESTS USER AGENT"
    }
    public func onUpdate(serverTime: Int64) {

    }
    public func isReachable() -> Bool {
        return true
    }
    public func onDohTroubleshot() { }
}
