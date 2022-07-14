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
    weak var delegate: NetworkingMockDelegate?

    var apiURLString = ""

    var apiService: PMAPIService {
        fatalError()
    }

    var requestCallback: ((URLRequest) -> Result<Data, Error>)?

    func request(_ route: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        if let delegate = delegate {
            completion(delegate.handleMockNetworkingRequest(route))
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

protocol NetworkingMockDelegate: AnyObject {
    func handleMockNetworkingRequest(_ request: URLRequest) -> Result<Data, Error>
}

class FullNetworkingMockDelegate: NetworkingMockDelegate {
    var apiServerList: [ServerModel] = []
    var apiCredentials: VpnCredentials?
    var apiVpnLocation: MockTestData.VPNLocationResponse?
    var apiClientConfig: ClientConfig?

    func handleMockNetworkingRequest(_ request: URLRequest) -> Result<Data, Error> {
        switch request.url?.path {
        case "/vpn":
            // for fetching client credentials
            guard let apiCredentials = apiCredentials else {
                return .failure(ApiError(httpStatusCode: 400, code: 2000))
            }

            let data = try! JSONSerialization.data(withJSONObject: apiCredentials.asDict)
            return .success(data)
        case "/vpn_status":
            // for checking p2p state
            return .success(Data())
        case "/vpn/location":
            // for checking IP state
            let response = apiVpnLocation!
            let data = try! responseEncoder.encode(response)
            return .success(data)
        case "/vpn/logicals":
            // for fetching server list
            let servers = self.apiServerList.map { $0.asDict }
            let data = try! JSONSerialization.data(withJSONObject: [
                "LogicalServers": servers
            ])

            return .success(data)
        case "/vpn/streamingservices":
            // for fetching list of streaming services & icons
            let response = VPNStreamingResponse(code: 1000,
                                                resourceBaseURL: "https://protonvpn.com/resources",
                                                streamingServices: ["IT": [
                                                    "1": [.init(name: "Rai", icon: "rai.jpg")],
                                                    "2": [.init(name: "Netflix", icon: "netflix.jpg")]
                                                ]])
            let data = try! responseEncoder.encode(response)
            return .success(data)
        case "/vpn/v2/clientconfig":
            let response = ClientConfigResponse(clientConfig: apiClientConfig!)
            let data = try! responseEncoder.encode(response)
            return .success(data)
        default:
            fatalError("Request not implemented: \(request)")
        }
    }

    private lazy var responseEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .capitalizeFirstLetter
        return encoder
    }()
}

private extension JSONEncoder.KeyEncodingStrategy {
    static let capitalizeFirstLetter = Self.custom { path in
        let original: String = path.last!.stringValue
        let capitalized = original.prefix(1).uppercased() + original.dropFirst()
        return JSONKey(stringValue: capitalized) ?? path.last!
    }

    private struct JSONKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
}
