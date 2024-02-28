//
//  Created on 2022-10-19.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import XCTest

import Domain
import TimerMock
@testable import NEHelper
@testable import VPNShared
@testable import VPNSharedTesting

/// Base class for tests that exercise the ExtensionAPIService object.
/// This object is used in network extensions for things like refreshing the connection's certificate
/// and checking the maintenance status of servers.
class ExtensionAPIServiceTestCase: XCTestCase, ExtensionAPIServiceDelegate {
    typealias MockEndpointBlock = ((URLRequest, @escaping MockDataTask.CompletionCallback) -> ())

    let expectationTimeout: TimeInterval = 10

    static let sessionSelector = "SELECTOR"
    static var currentLogicalId = "logical-id"
    static var currentServerIpId = "server-ip-id"
    static let sessionCookie = HTTPCookie(properties: [.name: "COOOKIEE",
                                                       .value: "OM NOM NOM NOM",
                                                       .version: 2,
                                                       .path: "/",
                                                       .domain: "piv.pivpiv.dk",
                                                       .maximumAge: "420"])!

    static let defaultVpnFeatures = VPNConnectionFeatures(netshield: .off,
                                                          vpnAccelerator: true,
                                                          bouncing: "bouncing",
                                                          natType: .moderateNAT,
                                                          safeMode: true)

    /// All callbacks are set to this in `setUp()`
    let failCallback: MockEndpointBlock = { _, _ in
        XCTFail("This test was not supposed to exercise this endpoint, or the endpoint needs to be set.")
    }

    var certRefreshCallback: MockEndpointBlock?
    var tokenRefreshCallback: MockEndpointBlock?
    var sessionAuthCallback: MockEndpointBlock?
    var serverStatusCallback: MockEndpointBlock?

    var keychain: MockAuthKeychain!
    var mockDataTaskFactory: MockDataTaskFactory!
    var authenticationStorage: MockVpnAuthenticationStorage!
    var timerFactory: TimerFactoryMock!
    var apiService: ExtensionAPIService!

    let testQueue = DispatchQueue(label: "ch.protonvpn.tests.certificaterefresh")

    // ExtensionAPIServiceDelegate
    let transport: WireGuardTransport? = .udp
    var dataTaskFactory: DataTaskFactory! {
        mockDataTaskFactory
    }

    // For testing if the feature flag works, can be safely removed once the `CertificateRefreshForceRenew` feature
    // flag is no longer in use
    var forceRenew: Bool {
        get {
            ExtensionAPIService.forceEvictAnyPreviousSessionAssociatedKeysToAvoidConflictErrors
        }
        set {
            ExtensionAPIService.forceEvictAnyPreviousSessionAssociatedKeysToAvoidConflictErrors = newValue
        }
    }

    struct MockAPIEndpointError: Error {
        let httpError: APIHTTPErrorCode
        let apiError: APIError?

        // API error codes should be ignored by the cert refresh manager for clearly-defined HTTP error cases.
        static let tokenExpired = Self(httpError: .tokenExpired,
                                       apiError: .init(code: 15213, message: "Token expired"))
        static let sessionExpired = Self(httpError: .unprocessableEntity,
                                         apiError: .init(code: APIJSONErrorCode.invalidAuthToken.rawValue,
                                                         message: "Session expired"))
        static let tooManyRequests = Self(httpError: .tooManyRequests,
                                          apiError: .init(code: 15213, message: "You need to calm down"))
        static let serviceUnavailable = Self(httpError: .serviceUnavailable, apiError: nil)
        static let internalError = Self(httpError: .internalError, apiError: nil)
    }

    override func setUp() async throws {
        AppContext.default = .wireGuardExtension

        mockDataTaskFactory = MockDataTaskFactory { session, request, completionHandler in
            switch request.url?.path {
            case "/vpn/v1/certificate":
                self.certRefreshCallback?(request, completionHandler)
            case "/auth/refresh":
                self.tokenRefreshCallback?(request, completionHandler)
            case "/auth/v4/sessions/forks/\(Self.sessionSelector)":
                self.sessionAuthCallback?(request, completionHandler)
            case "/vpn/v1/logicals/\(Self.currentLogicalId)/alternatives":
                self.serverStatusCallback?(request, completionHandler)
            case nil:
                XCTFail("Received request with no path")
            default:
                XCTFail("Unhandled case")
            }
        }
        authenticationStorage = MockVpnAuthenticationStorage()
        authenticationStorage.keys = VpnKeys.mock()
        authenticationStorage.features = Self.defaultVpnFeatures

        certRefreshCallback = failCallback
        tokenRefreshCallback = failCallback
        sessionAuthCallback = failCallback
        serverStatusCallback = failCallback

        keychain = MockAuthKeychain()
        try! keychain.store(AuthCredentials(username: "johnny",
                                                  accessToken: "12345",
                                                  refreshToken: "54321",
                                                  sessionId: "15213",
                                                  userId: "bravo",
                                                  scopes: []))
        timerFactory = TimerFactoryMock()

        apiService = ExtensionAPIService(timerFactory: timerFactory,
                                         keychain: keychain,
                                         appInfo: AppInfoImplementation(),
                                         atlasSecret: "")

        apiService.delegate = self
    }

    /// Generate an "endpoint" closure that can mock various API responses or error cases.
    ///
    /// - Parameter cls: The response type to use.
    /// - Parameter result: This can either be a success condition with the data to return, or the error to throw.
    /// - Parameter expectationToFulfill: When the returned callback gets called, it will fulfill the passed expectation.
    /// - Returns: A closure that will call the passed completion handler with a fake HTTP 200 response
    ///            and its encoded data; a fake HTTP error response with an optional corresponding API error
    ///            also encoded as JSON; or no HTTP response or data at all and the error paremeter populated
    ///            with an error result of the caller's choosing.
    func mockEndpoint<M: MockableRequest>(_ cls: M.Type,
                                          result: Result<[PartialKeyPath<M.Response>: Any], Error>,
                                          responseHeaders: [APIHeader: String] = [:],
                                          expectationToFulfill: XCTestExpectation) -> MockEndpointBlock {
        return { request, completionHandler in
            var headers: [String: String] = [:]
            for (header, value) in responseHeaders {
                headers[header.rawValue] = value
            }

            switch result {
            case .success(let responseData):
                let response = HTTPURLResponse(url: request.url!,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: headers)

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .secondsSince1970
                let data = try! encoder.encode(M.Response(fakeData: responseData))

                self.testQueue.async {
                    completionHandler(data, response, nil)
                    expectationToFulfill.fulfill()
                }
            case .failure(let error):
                if let mockAPIError = error as? MockAPIEndpointError {
                    let response = HTTPURLResponse(url: request.url!,
                                                   statusCode: mockAPIError.httpError.rawValue,
                                                   httpVersion: nil,
                                                   headerFields: headers)

                    var data: Data?
                    if let apiError = mockAPIError.apiError {
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .secondsSince1970
                        data = try! encoder.encode(apiError)
                    }

                    self.testQueue.async {
                        completionHandler(data, response, nil)
                        expectationToFulfill.fulfill()
                    }
                } else {
                    self.testQueue.async {
                        completionHandler(nil, nil, error)
                        expectationToFulfill.fulfill()
                    }
                }
            }
        }
    }

    /// Convenience function for mock API error cases
    func mockEndpoint<M: MockableRequest>(_ cls: M.Type,
                                                  apiFailure: MockAPIEndpointError,
                                                  responseHeaders: [APIHeader: String] = [:],
                                                  expectationToFulfill: XCTestExpectation) -> MockEndpointBlock {
        mockEndpoint(cls,
                     result: .failure(apiFailure),
                     responseHeaders: responseHeaders,
                     expectationToFulfill: expectationToFulfill)
    }

}

protocol MockableAPIResponse: Codable {
    init(fakeData: [PartialKeyPath<Self>: Any])
}

protocol MockableRequest {
    associatedtype Response: MockableAPIResponse
}

extension CertificateRefreshRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.init(certificate: fakeData[\.certificate] as? String ?? "certificate",
                  validUntil: fakeData[\.validUntil] as? Date ?? Date(),
                  refreshTime: fakeData[\.refreshTime] as? Date ?? Date())
    }
}

extension CertificateRefreshRequest: MockableRequest {
}

extension TokenRefreshRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.init(accessToken: fakeData[\.accessToken] as? String ?? "accessToken",
                  refreshToken: fakeData[\.refreshToken] as? String ?? "refreshToken",
                  expiresIn: fakeData[\.expiresIn] as? TimeInterval ?? 15)
    }
}

extension TokenRefreshRequest: MockableRequest {
}

extension SessionAuthRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.init(uid: fakeData[\.uid] as? String ?? "uid",
                  refreshToken: fakeData[\.refreshToken] as? String ?? "refreshToken")
    }
}

extension SessionAuthRequest: MockableRequest {
}

extension ServerStatusRequest: MockableRequest {
}

extension ServerStatusRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<ServerStatusRequest.Response>: Any]) {
        let code = fakeData[\.code] as? Int ?? 1000
        let original = fakeData[\.original] as? ServerStatusRequest.Logical ?? ServerStatusRequest.Logical(id: "logical-id", status: 1, servers: [.mock(id: "server-ip-id", status: 1)])
        let alternatives = fakeData[\.alternatives] as? [ServerStatusRequest.Logical] ?? [ServerStatusRequest.Logical(id: "other-logical-id", status: 1, servers: [.mock(id: "other-server-id", status: 1)])]
        
        self.init(code: code, original: original, alternatives: alternatives)
    }
}
