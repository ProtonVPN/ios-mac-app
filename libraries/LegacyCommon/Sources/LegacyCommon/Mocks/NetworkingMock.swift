//
//  NetworkingMock.swift
//  Core
//
//  Created by Igor Kulman on 25.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

#if DEBUG
import Foundation
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonCoreAuthentication
import ProtonCoreFoundations
import VPNShared
import ProtonCoreEnvironment

import XCTestDynamicOverlay

public final class NetworkingMock {
    public weak var delegate: NetworkingMockDelegate?

    var apiURLString = ""

    public var apiService: PMAPIService {
        TrustKitWrapper.setUp()
        let tk = TrustKitWrapper.current

        PMAPIService.trustKit = tk
        PMAPIService.noTrustKit = (tk == nil)

        return PMAPIService.createAPIService(doh: DoHVPN(apiHost: "", verifyHost: "", alternativeRouting: false, appState: .disconnected),
                                      sessionUID: "UID",
                                      challengeParametersProvider: ChallengeParametersProvider.empty
        )
    }

    public var requestCallback: ((URLRequest) -> Result<Data, Error>)?

    public init() { }

    func request(_ route: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        if let delegate = delegate {
            completion(delegate.handleMockNetworkingRequest(route))
        } else {
            completion(.success(try! JSONEncoder().encode(["key": "value"])))
        }
    }

    func request(_ route: Request, completion: @escaping (Result<Data, Error>) -> Void) {
        var urlRequest = Foundation.URLRequest(url: URL(string: "\(apiURLString)\(route.path)")!)
        urlRequest.httpMethod = route.method.rawValue

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
    public func perform(request route: Request) async throws -> JSONDictionary {
        try await withCheckedThrowingContinuation { continuation in
            request(route) { (result: Result<Data, Error>) in
                switch result {
                case let .success(data):
                    guard let dict = data.jsonDictionary else {
                        continuation.resume(throwing: POSIXError(.EBADMSG))
                        return
                    }
                    continuation.resume(returning: dict)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func perform<R>(request route: Request) async throws -> R where R : Decodable {
        try await withCheckedThrowingContinuation { continuation in
            request(route) { (result: Result<Data, Error>) in
                switch result {
                case let .success(data):
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                        let obj = try decoder.decode(R.self, from: data)
                        continuation.resume(returning: obj)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func request(_ route: Request, completion: @escaping (Result<JSONDictionary, Error>) -> Void) {
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

    public func request(_ route: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {
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

    public func request<T>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
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
    public func request<T>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
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

public protocol NetworkingMockDelegate: AnyObject {
    func handleMockNetworkingRequest(_ request: URLRequest) -> Result<Data, Error>
}

public class FullNetworkingMockDelegate: NetworkingMockDelegate {
    public enum MockEndpoint: String {
        case vpn = "/vpn/v2"
        case status = "/vpn_status"
        case location = "/vpn/v1/location"
        case logicals = "/vpn/v1/logicals"
        case streamingServices = "/vpn/v1/streamingservices"
        case partners = "/vpn/v1/partners"
        case clientConfig = "/vpn/v2/clientconfig"
        case loads = "/vpn/v1/loads"
        case certificate = "/vpn/v1/certificate"
        case sessionCount = "/vpn/sessioncount"
    }

    public struct UnexpectedError: Error {
        let description: String
    }

    public var apiServerList: [ServerModel] = []
    public var apiServerLoads: [ContinuousServerProperties] = []
    public var apiCredentials: VpnCredentials?

    public var apiCredentialsResponseError: ResponseError?
    public var apiVpnLocation: MockTestData.VPNLocationResponse?
    public var apiClientConfig: ClientConfig?

    public var didHitRoute: ((MockEndpoint) -> Void)?

    public init() { }

    public func handleMockNetworkingRequest(_ request: URLRequest) -> Result<Data, Error> {
        do {
            return try handleMockNetworkingRequestThrowingOnUnexpectedError(request)
        } catch {
            XCTFail("Unexpected error occurred: \(error)")
            return .failure(error)
        }
    }

    /// Any error returned via `Result.failure()` will be treated as a mock error, and thus part of the test.
    /// Any error thrown from this function will be treated as an unexpected error, and will thus fail the test.
    func handleMockNetworkingRequestThrowingOnUnexpectedError(_ request: URLRequest) throws -> Result<Data, Error> { // swiftlint:disable:this function_body_length cyclomatic_complexity
        guard let url = request.url else {
            throw UnexpectedError(description: "No path provided to URL request")
        }

        guard let route = MockEndpoint(rawValue: url.path) else {
            throw UnexpectedError(description: "Request not implemented: \(url.path)")
        }

        defer { didHitRoute?(route) }
        switch route {
        case .vpn:
            if let apiCredentialsResponseError {
                return .failure(apiCredentialsResponseError)
            }
            // for fetching client credentials
            guard let apiCredentials = apiCredentials else {
                return .failure(ResponseError(
                    httpCode: HttpStatusCode.badRequest,
                    responseCode: 2000,
                    userFacingMessage: nil,
                    underlyingError: nil
                ))
            }

            let data = try JSONSerialization.data(withJSONObject: apiCredentials.asDict)
            return .success(data)
        case .status:
            // for checking p2p state
            return .success(Data())
        case .location:
            // for checking IP state
            let response = apiVpnLocation ?? .mock
            let data = try responseEncoder.encode(response)
            return .success(data)
        case .logicals:
            var serverList = apiServerList

            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
               queryItems.contains(where: { $0.name == "Tier" && $0.value == "0" }) {
                serverList = serverList.filter { $0.isFree }
            }

            // for fetching server list
            let servers = serverList.map { $0.asDict }
            let data = try JSONSerialization.data(withJSONObject: [
                "LogicalServers": servers
            ])

            return .success(data)
        case .streamingServices:
            // for fetching list of streaming services & icons
            let response = VPNStreamingResponse(code: 1000,
                                                resourceBaseURL: "https://protonvpn.com/resources",
                                                streamingServices: ["IT": [
                                                    "1": [.init(name: "Rai", icon: "rai.jpg")],
                                                    "2": [.init(name: "Netflix", icon: "netflix.jpg")]
                                                ]])
            let data = try responseEncoder.encode(response)
            return .success(data)
        case .partners:
            // for fetching list of partners
            let response = VPNPartnersResponse(code: 1000, partnerTypes: [.onePartner()])
            let data = try responseEncoder.encode(response)
            return .success(data)
        case .clientConfig:
            let response = ClientConfigResponse(clientConfig: apiClientConfig!)
            let data = try responseEncoder.encode(response)
            return .success(data)
        case .loads:
            guard verifyClientIPIsMasked(request: request) else {
                return .failure(POSIXError(.EINVAL))
            }

            let servers = self.apiServerLoads.map { $0.asDict }
            let data = try JSONSerialization.data(withJSONObject: [
                "LogicalServers": servers
            ])
            return .success(data)
        case .certificate:
            let refreshTime = Date().addingTimeInterval(.hours(6))
            let expiryTime = refreshTime.addingTimeInterval(.hours(6))
            let certDict: [String: Any] = ["Certificate": "abcd1234",
                                           "ExpirationTime": Int(expiryTime.timeIntervalSince1970),
                                           "RefreshTime": Int(refreshTime.timeIntervalSince1970)]
            let data = try JSONSerialization.data(withJSONObject: certDict)
            return .success(data)
        case .sessionCount:
            let sessionCountDict: [String: Any] = ["sessionCount": 0]
            let data = try JSONSerialization.data(withJSONObject: sessionCountDict)
            return .success(data)
        }
    }

    func verifyClientIPIsMasked(request: URLRequest) -> Bool {
        guard let ip = request.headers["x-pm-netzone"] else {
            return true // no IP in request
        }

        let (ipDigits, dot, zero) = (#"\d{1,3}"#, #"\."#, #"0"#)
        let pattern = ipDigits + dot +
                      ipDigits + dot +
                      ipDigits + dot + zero // e.g., 123.123.123.0

        guard ip.hasMatches(for: pattern) else {
            log.assertionFailure("'\(ip)' does not match regex \(pattern), is it being masked properly?")
            return false
        }
        return true
    }

    private var responseEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .capitalizeFirstLetter
        return encoder
    }
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
#endif
