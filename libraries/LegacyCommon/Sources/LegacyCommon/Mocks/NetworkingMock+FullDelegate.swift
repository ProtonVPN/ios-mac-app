//
//  Created on 30/04/2024.
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

#if DEBUG
import Foundation

import XCTestDynamicOverlay

import CommonNetworking
import CommonNetworkingTestSupport
import Domain
import ProtonCoreNetworking

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
        // We cannot easily use `XCTUnwrap` here, since `LegacyCommon` imports this module.
        // Until we move mocks from `LegacyCommon` into `LegacyCommonTestSupport`, we cannot import `XCTest` here.
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
                    httpCode: HttpStatusCode.badRequest.rawValue,
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

    private let responseEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .capitalizeFirstLetter
        return encoder
    }()
}

#endif
