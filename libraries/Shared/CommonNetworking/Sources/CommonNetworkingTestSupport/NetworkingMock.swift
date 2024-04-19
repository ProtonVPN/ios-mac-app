//
//  Created on 22/04/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

// This is a test-only module, but mocks are still wrapped in `#if DEBUG` because `LegacyCommon` imports this module in
// due to previous linking issues.
#if DEBUG
import Foundation

import ProtonCoreAuthentication
import ProtonCoreEnvironment
import ProtonCoreFoundations
import ProtonCoreNetworking
import ProtonCoreServices

@testable import CommonNetworking
import Domain
import VPNShared

import XCTestDynamicOverlay

// Ensure mock network requests are quick for fast unit/integration tests
private let maxMockRequestTime: TimeInterval = 0.1

public final class NetworkingMock {
    public weak var delegate: NetworkingMockDelegate?

    var apiURLString = ""

    public var apiService: PMAPIService {
        TrustKitWrapper.setUp()
        let tk = TrustKitWrapper.current

        PMAPIService.trustKit = tk
        PMAPIService.noTrustKit = (tk == nil)

        return PMAPIService.createAPIService(
            doh: DoHVPN.mock,
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
        let start = Date()
        request(route) { (result: Result<Data, Error>) in
            let elapsedTime = Date().timeIntervalSince(start)
            if elapsedTime > maxMockRequestTime {
                let elapsedMillis = (elapsedTime * 1000).rounded()
                log.warning("Mock network request on \(route) exceeded maximum allowed time: \(elapsedMillis)ms")
                // VPNAPPL-2129: There is no reason for a fully mocked request to take even a fraction of this time
                // Re-enable this assertion once we find out the root cause of long/blocked mock requests.
                // XCTFail("Mock network request on \(route) exceeded maximum allowed time: \(elapsedMillis)ms")
            }
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

    public func request(
        _ route: ConditionalRequest,
        completion: @escaping (Result<IfModifiedSinceResponse<JSONDictionary>, Error>) -> Void
    ) {
        request(route) { (result: Result<Data, Error>) in
            switch result {
            case let .success(data):
                guard let dict = data.jsonDictionary else {
                    completion(.failure(POSIXError(.EBADMSG)))
                    return
                }

                completion(.success(.modified(at: "", value: dict)))
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

extension JSONEncoder.KeyEncodingStrategy {
    public static let capitalizeFirstLetter = Self.custom { path in
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

// MARK: API Response Encodable Conformances

extension ClientConfigResponse: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(clientConfig.featureFlags, forKey: .featureFlags)
        try container.encode(clientConfig.serverRefreshInterval, forKey: .serverRefreshInterval)
        try container.encode(clientConfig.smartProtocolConfig, forKey: .smartProtocol)
        try container.encode(clientConfig.ratingSettings, forKey: .ratingSettings)
        // encoded directly into the parent object without a container. See `ServerChangeConfig` docs for more info
        try clientConfig.serverChangeConfig.encode(to: encoder)

        let defaultPorts = [
            ProtocolType.WireGuard: [
                PortType.UDP: clientConfig.wireGuardConfig.defaultUdpPorts,
                PortType.TCP: clientConfig.wireGuardConfig.defaultTcpPorts
            ],
        ]
        try container.encode(defaultPorts, forKey: .defaultPorts)
    }
}
#endif
