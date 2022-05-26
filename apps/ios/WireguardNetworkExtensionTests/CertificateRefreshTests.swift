//
//  Created on 2022-04-21.
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

class CertificateRefreshTests: XCTestCase {
    typealias MockEndpointBlock = ((URLRequest, @escaping MockDataTask.CompletionCallback) -> ())

    let expectationTimeout: TimeInterval = 10

    static let sessionSelector = "SELECTOR"
    static let defaultVpnFeatures = VPNConnectionFeatures(netshield: .off,
                                                          vpnAccelerator: true,
                                                          bouncing: "bouncing",
                                                          natType: .moderateNAT,
                                                          safeMode: true)

    /// All callbacks are set to this in `setUpWithError()`
    let failCallback: MockEndpointBlock = { _, _ in
        XCTFail("This test was not supposed to exercise this endpoint, or the endpoint needs to be set.")
    }

    var certRefreshCallback: MockEndpointBlock?
    var tokenRefreshCallback: MockEndpointBlock?
    var sessionAuthCallback: MockEndpointBlock?

    var keychain: MockAuthKeychain!
    var dataTaskFactory: MockDataTaskFactory!
    var authenticationStorage: MockVpnAuthenticationStorage!
    var timerFactory: MockTimerFactory!
    var apiService: ExtensionAPIService!
    var manager: ExtensionCertificateRefreshManager!

    let testQueue = DispatchQueue(label: "ch.protonvpn.tests.certificaterefresh")

    private struct MockAPIEndpointError: Error {
        let httpError: APIHTTPErrorCode
        let apiError: APIError?

        // API error codes should be ignored by the cert refresh manager for clearly-defined HTTP error cases.
        static let tokenExpired = Self(httpError: .tokenExpired,
                                       apiError: .init(code: 15213, message: "Token expired"))
        static let sessionExpired = Self(httpError: .sessionExpired,
                                         apiError: .init(code: 15213, message: "Session expired"))
        static let tooManyRequests = Self(httpError: .tooManyRequests,
                                          apiError: .init(code: 15213, message: "You need to calm down"))
        static let serviceUnavailable = Self(httpError: .serviceUnavailable, apiError: nil)
        static let internalError = Self(httpError: .internalError, apiError: nil)
    }

    override func setUpWithError() throws {
        dataTaskFactory = MockDataTaskFactory { session, request, completionHandler in
            switch request.url?.path {
            case "/vpn/v1/certificate":
                self.certRefreshCallback?(request, completionHandler)
            case "/auth/refresh":
                self.tokenRefreshCallback?(request, completionHandler)
            case "/auth/sessions/forks/\(Self.sessionSelector)":
                self.sessionAuthCallback?(request, completionHandler)
            case nil:
                XCTFail("Received request with no path")
            default:
                XCTFail("Unhandled case")
            }
        }

        let storage = Storage()
        authenticationStorage = MockVpnAuthenticationStorage()
        authenticationStorage.keys = VpnKeys()
        authenticationStorage.features = Self.defaultVpnFeatures

        certRefreshCallback = failCallback
        tokenRefreshCallback = failCallback
        sessionAuthCallback = failCallback

        keychain = MockAuthKeychain()
        keychain.credentials = AuthCredentials(username: "johnny",
                                               accessToken: "12345",
                                               refreshToken: "54321",
                                               sessionId: "15213",
                                               userId: "bravo",
                                               expiration: Date().addingTimeInterval(60 * 20),
                                               scopes: [])

        timerFactory = MockTimerFactory()

        apiService = ExtensionAPIService(storage: storage,
                                         dataTaskFactory: dataTaskFactory,
                                         timerFactory: timerFactory,
                                         keychain: keychain)

        self.manager = ExtensionCertificateRefreshManager(apiService: apiService,
                                                          timerFactory: timerFactory,
                                                          vpnAuthenticationStorage: authenticationStorage,
                                                          keychain: keychain)

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
    private func mockEndpoint<M: MockableRequest>(_ cls: M.Type,
                                                  apiFailure: MockAPIEndpointError,
                                                  responseHeaders: [APIHeader: String] = [:],
                                                  expectationToFulfill: XCTestExpectation) -> MockEndpointBlock {
        mockEndpoint(cls,
                     result: .failure(apiFailure),
                     responseHeaders: responseHeaders,
                     expectationToFulfill: expectationToFulfill)
    }

    func testNormalCertRefresh() {
        let expectations = (
            certRefresh: XCTestExpectation(description: "Wait for certificate refresh request"),
            certResponse: XCTestExpectation(description: "Wait for response from cert refresh")
        )

        let testValues = (
            cert: "This is a certificate",
            refreshTime: Date().addingTimeInterval(15),
            validUntil: Date().addingTimeInterval(20)
        )

        certRefreshCallback = mockEndpoint(CertificateRefreshRequest.self,
                                           result: .success([\.certificate: testValues.cert,
                                                             \.refreshTime: testValues.refreshTime,
                                                             \.validUntil: testValues.validUntil]),
                                           expectationToFulfill: expectations.certRefresh)

        manager.start {
            self.manager.checkRefreshCertificateNow(features: self.authenticationStorage.features!) { result in
                expectations.certResponse.fulfill()
            }
        }

        wait(for: [expectations.certRefresh, expectations.certResponse], timeout: expectationTimeout)

        guard let cert = self.authenticationStorage.getStoredCertificate() else {
            XCTFail("No certificate stored")
            return
        }

        XCTAssertEqual(cert.certificate, testValues.cert)
        XCTAssertEqual(cert.validUntil.formatted(), testValues.validUntil.formatted())
        XCTAssertEqual(cert.refreshTime.formatted(), testValues.refreshTime.formatted())
    }

    /// An error 401 means that the API token has expired. This case tests that, upon receiving a 401, the
    /// certificate refresh manager knows it needs to refresh the API token.
    func testError401LeadingToTokenRefresh() {
        let expectationForFirstCertRefresh = XCTestExpectation(description: "Wait for first certificate refresh")
        let expectationForRetryCertRefresh = XCTestExpectation(description: "Wait for subsequent certificate refresh")
        let expectationForAuthTokenRefresh = XCTestExpectation(description: "Wait to request new token from API")
        var certRefreshRequests = 0
        var tokenRefreshRequests = 0

        certRefreshCallback = { request, completionHandler in
            if certRefreshRequests == 0 {
                certRefreshRequests = 1
                let callback = self.mockEndpoint(CertificateRefreshRequest.self,
                                                 result: .failure(MockAPIEndpointError.tokenExpired),
                                                 expectationToFulfill: expectationForFirstCertRefresh)

                callback(request, completionHandler)
            } else {
                XCTAssertEqual(certRefreshRequests, 1, "Should have only asked for cert refresh one other time")
                certRefreshRequests += 1

                let callback = self.mockEndpoint(CertificateRefreshRequest.self,
                                                 result: .success([:]),
                                                 expectationToFulfill: expectationForRetryCertRefresh)
                callback(request, completionHandler)
            }
        }

        tokenRefreshCallback = { request, completionHandler in
            if tokenRefreshRequests == 0 {
                tokenRefreshRequests = 1
                XCTAssertEqual(certRefreshRequests, 1, "Should have asked for new cert before token refresh")
            } else {
                XCTFail("Should have only requested token refresh once")
                tokenRefreshRequests += 1
            }
            let callback = self.mockEndpoint(TokenRefreshRequest.self,
                                             result: .success([:]),
                                             expectationToFulfill: expectationForAuthTokenRefresh)
            callback(request, completionHandler)
        }

        timerFactory.timerWasAdded = {
            self.timerFactory.runRepeatingTimers()
        }

        manager.start { }

        wait(for: [expectationForFirstCertRefresh,
                   expectationForRetryCertRefresh,
                   expectationForAuthTokenRefresh], timeout: expectationTimeout)
    }

    /// An error 422 means that the API session (not the token) has expired. The network extension can do
    /// nothing but wait for the app to check in with the extension again. When it does, it should fork
    /// its session again and the network extension should use this selector to re-authenticate.
    func testError422LeadingToSessionExpiryThenSessionRenewal() {
        let expectations = (
            firstCertRefresh: XCTestExpectation(description: "Wait for first certificate refresh"),
            secondCertRefresh: XCTestExpectation(description: "Wait for second certificate refresh"),
            thirdCertRefresh: XCTestExpectation(description: "Wait for third certificate refresh"),
            tokenRefresh: XCTestExpectation(description: "Wait for token refresh"),
            sessionAuth: XCTestExpectation(description: "Wait for session auth"),
            managerRestart: XCTestExpectation(description: "Wait for manager restart")
        )

        let testValues = (
            // API token
            refreshToken: "abc123",
            accessToken: "def456",
            expiresIn: 60 * 2,

            // Certificate
            cert: "This is a certificate",
            refreshTime: Date().addingTimeInterval(15),
            validUntil: Date().addingTimeInterval(20)
        )

        certRefreshCallback = mockEndpoint(CertificateRefreshRequest.self,
                                           result: .failure(MockAPIEndpointError.sessionExpired),
                                           expectationToFulfill: expectations.firstCertRefresh)

        tokenRefreshCallback = mockEndpoint(TokenRefreshRequest.self,
                                            result: .success([
                                                \.accessToken: testValues.accessToken,
                                                \.refreshToken: testValues.refreshToken,
                                                \.expiresIn: Double(testValues.expiresIn)]),
                                            expectationToFulfill: expectations.tokenRefresh)

        sessionAuthCallback = mockEndpoint(SessionAuthRequest.self,
                                           result: .success([:]),
                                           expectationToFulfill: expectations.sessionAuth)


        timerFactory.timerWasAdded = {
            self.timerFactory.runRepeatingTimers()
        }

        manager.start { }

        // Manager should try the first cert refresh, and get a 422 as a response.
        wait(for: [expectations.firstCertRefresh], timeout: expectationTimeout)

        certRefreshCallback = { _, _ in
            XCTFail("Shouldn't try cert refresh again after receiving session expiration error")
        }

        // If we try to go again, we should get a session expired error, *without* querying the endpoint.
        manager.checkRefreshCertificateNow(features: authenticationStorage.features!) { result in
            defer { expectations.secondCertRefresh.fulfill() }

            XCTAssertTrue(self.apiService.sessionExpired)

            guard case let .failure(error) = result, case .sessionExpiredOrMissing = error else {
                XCTFail("Request should have failed with expired session")
                return
            }
        }

        wait(for: [expectations.secondCertRefresh], timeout: expectationTimeout)

        // Now change the cert refresh so that it returns a normal response.
        certRefreshCallback = mockEndpoint(CertificateRefreshRequest.self,
                                           result: .success([
                                               \.certificate: testValues.cert,
                                               \.refreshTime: testValues.refreshTime,
                                               \.validUntil: testValues.validUntil]),
                                           expectationToFulfill: expectations.thirdCertRefresh)

        manager.newSession(withSelector: Self.sessionSelector) { result in
            defer { expectations.managerRestart.fulfill() }

            if case let .failure(error) = result {
                XCTFail("Restarting manager failed with error: \(error)")
            }
        }

        wait(for: [expectations.sessionAuth,
                   expectations.tokenRefresh,
                   expectations.managerRestart,
                   expectations.thirdCertRefresh], timeout: expectationTimeout)
    }

    /// If the network extension starts up and realizes it has no credentials in the keychain, it should
    /// immediately stop and wait for the main app to check in and provide it with a session selector.
    func testManagerStartWithEmptyAPICredentials() {
        keychain.credentials = nil
        let expectations = (
            firstCertRefresh: XCTestExpectation(description: "First certificate refresh"),
            managerStart: XCTestExpectation(description: "Certificate manager start")
        )

        manager.start {
            expectations.managerStart.fulfill()
            self.manager.checkRefreshCertificateNow(features: self.authenticationStorage.features!) { result in
                defer { expectations.firstCertRefresh.fulfill() }

                guard case let .failure(error) = result else {
                    XCTFail("Shouldn't be able to refresh cert with missing credentials")
                    return
                }

                guard case .sessionExpiredOrMissing = error else {
                    XCTFail("Expected 'sessionExpired' error but got \(error)")
                    return
                }
            }
        }

        wait(for: [expectations.managerStart, expectations.firstCertRefresh], timeout: expectationTimeout)
    }

    /// If the certificate doesn't meet the refresh requirements (see `certificateDoesNeedRefreshing(features:)`),
    /// then the refresh manager should make no API calls. (Update this test if you are updating the
    /// aforementioned function.)
    func testRefreshingDoesNothingWhenRefreshConditionsAreNotMet() {
        let features = VPNConnectionFeatures(netshield: .level1,
                                             vpnAccelerator: true,
                                             bouncing: "bouncing",
                                             natType: .moderateNAT,
                                             safeMode: true)
        let cert = VpnCertificate(fakeData: [
            \.certificate: "This is a certificate",
            \.refreshTime: Date().addingTimeInterval(60 * 60),
            \.validUntil: Date().addingTimeInterval(2 * 60 * 60)
        ])
        authenticationStorage.features = features
        authenticationStorage.cert = cert

        let expectation = XCTestExpectation(description: "Cert refresh should do nothing")

        manager.start {
            self.manager.checkRefreshCertificateNow(features: self.authenticationStorage.features!) { result in
                defer { expectation.fulfill() }

                if case let .failure(error) = result {
                    XCTFail("Expected success, but got error instead: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: expectationTimeout)

        // cert and features should remain unchanged
        XCTAssertEqual(cert.certificate, authenticationStorage.cert?.certificate)
        XCTAssertEqual(cert.validUntil.formatted(),
                       authenticationStorage.cert?.validUntil.formatted())
        XCTAssertEqual(cert.refreshTime.formatted(),
                       authenticationStorage.cert?.refreshTime.formatted())
        XCTAssert(features.equals(other: authenticationStorage.features, safeModeEnabled: true))
    }

    /// If the certificate is still valid but the app is requesting a certificate for use with features different
    /// from what has been stored, the certificate should refresh.
    ///
    /// - Note: this case cannot test that the app doesn't update the stored features immediately before asking
    ///         for a refresh. If the app does this, the extension won't be able to notice that something changed.
    func testChangedFeaturesWithValidCertificateResultsInRefresh() {
        let expectations = (
            certRefresh: XCTestExpectation(description: "Manager should try to refresh cert"),
            certResponse: XCTestExpectation(description: "Should get response from API endpoint")
        )

        let testData = (
            currentCert: VpnCertificate(fakeData: [
                \.certificate: "This is a certificate",
                \.refreshTime: Date().addingTimeInterval(60 * 60),
                \.validUntil: Date().addingTimeInterval(2 * 60 * 60)
            ]),
            updatedCert: VpnCertificate(fakeData: [
                \.certificate: "This is a new certificate",
                \.refreshTime: Date().addingTimeInterval(20 * 60),
                \.validUntil: Date().addingTimeInterval(1 * 60 * 60)
            ])
        )

        certRefreshCallback = mockEndpoint(CertificateRefreshRequest.self,
                                           result: .success([
                                               \.certificate: testData.updatedCert.certificate,
                                               \.refreshTime: testData.updatedCert.refreshTime,
                                               \.validUntil: testData.updatedCert.validUntil
                                           ]),
                                           expectationToFulfill: expectations.certRefresh)

        let newFeatures = VPNConnectionFeatures(netshield: .level1,
                                                vpnAccelerator: true,
                                                bouncing: "bouncing",
                                                natType: .moderateNAT,
                                                safeMode: true)

        authenticationStorage.cert = testData.currentCert

        manager.start {
            self.manager.checkRefreshCertificateNow(features: newFeatures) { result in
                defer { expectations.certResponse.fulfill() }

                if case let .failure(error) = result {
                    XCTFail("Expected refresh success but got error: \(error)")
                }
            }
        }

        wait(for: [expectations.certRefresh, expectations.certResponse], timeout: expectationTimeout)

        XCTAssertEqual(testData.updatedCert.certificate, authenticationStorage.cert?.certificate)
        XCTAssertEqual(testData.updatedCert.validUntil.formatted(),
                       authenticationStorage.cert?.validUntil.formatted())
        XCTAssertEqual(testData.updatedCert.refreshTime.formatted(),
                       authenticationStorage.cert?.refreshTime.formatted())
    }

    /// If the features haven't changed but the certificate needs refreshing, the cert should be refreshed.
    func testExpiredCertWithSameFeaturesResultsInRefresh() {
        let expectations = (
            certRefresh: XCTestExpectation(description: "Manager should try to refresh cert"),
            certResponse: XCTestExpectation(description: "Should get response from API endpoint")
        )

        let testData = (
            expiredCert: VpnCertificate(fakeData: [
                \.validUntil: Date().addingTimeInterval(-7 * 60),
                \.refreshTime: Date().addingTimeInterval(-4 * 60),
                \.certificate: "This is an expired certificate"
            ]),
            updatedCert: VpnCertificate(fakeData: [:]) // just use default values, we don't care
        )

        authenticationStorage.cert = testData.expiredCert

        certRefreshCallback = mockEndpoint(CertificateRefreshRequest.self,
                                           result: .success([
                                               \.certificate: testData.updatedCert.certificate,
                                               \.refreshTime: testData.updatedCert.refreshTime,
                                               \.validUntil: testData.updatedCert.validUntil
                                           ]),
                                           expectationToFulfill: expectations.certRefresh)

        manager.start {
            self.manager.checkRefreshCertificateNow(features: self.authenticationStorage.features!) { result in
                defer { expectations.certResponse.fulfill() }

                if case let .failure(error) = result {
                    XCTFail("Expected refresh success but got error: \(error)")
                }
            }
        }

        wait(for: [expectations.certRefresh, expectations.certResponse], timeout: expectationTimeout)

        XCTAssertEqual(testData.updatedCert.certificate, authenticationStorage.cert?.certificate)
        XCTAssertEqual(testData.updatedCert.validUntil.formatted(),
                       authenticationStorage.cert?.validUntil.formatted())
        XCTAssertEqual(testData.updatedCert.refreshTime.formatted(),
                       authenticationStorage.cert?.refreshTime.formatted())
    }

    func testMultipleRequestsShouldEnqueueProperly() {
        // How many "simultaneous" requests we should simulate being enqueued in the refresh manager
        let requestIndices = 0..<10

        let expectations = (
            certRefresh: XCTestExpectation(description: "Wait for cert refresh request"),
            enqueuedRequests: requestIndices.map { index in
                XCTestExpectation(description: "Wait for cert refresh response completion #\(index)")
            }
        )

        let testData = (
            expiredCert: VpnCertificate(fakeData: [
                \.validUntil: Date().addingTimeInterval(-7 * 60),
                \.refreshTime: Date().addingTimeInterval(-4 * 60),
                \.certificate: "This is an expired certificate"
            ]),
            updatedCert: VpnCertificate(fakeData: [
                \.validUntil: Date().addingTimeInterval(7 * 60),
                \.refreshTime: Date().addingTimeInterval(4 * 60),
                \.certificate: "This is an updated certificate"
            ])
        )

        // Set an expired certificate to force the manager to refresh.
        authenticationStorage.cert = testData.expiredCert

        var already: Bool = false
        certRefreshCallback = { request, completionHandler in
            XCTAssertFalse(already, "Should only need to send this request once")
            already = true

            let callback = self.mockEndpoint(CertificateRefreshRequest.self,
                                             result: .success([
                                                 \.validUntil: testData.updatedCert.validUntil,
                                                 \.refreshTime: testData.updatedCert.refreshTime,
                                                 \.certificate: testData.updatedCert.certificate,
                                             ]),
                                             expectationToFulfill: expectations.certRefresh)

            sleep(1) // Give a little wait to let the requests pile up
            callback(request, completionHandler)
        }

        manager.start { }

        var incr = 0
        let incrQueue = DispatchQueue(label: "incr")
        _ = requestIndices.map { index in
            testQueue.async {
                self.manager.checkRefreshCertificateNow(features: self.authenticationStorage.features!) { result in
                    // get the sequence index, and assert that it matches up sequentially.
                    incrQueue.sync(flags: .barrier) {
                        XCTAssertEqual(incr, index)
                        incr += 1
                    }

                    if case let .failure(error) = result {
                        XCTFail("Didn't expect error in request #\(index): \(error)")
                    }

                    expectations.enqueuedRequests[index].fulfill()
                }
            }
        }

        wait(for: [expectations.certRefresh] + expectations.enqueuedRequests, timeout: expectationTimeout)
    }

    /// This is a longer test which attempts to exercise as much of the refresh manager's retry logic as possible.
    /// The scenario simulated is as follows:
    ///
    /// - A first cert refresh attempt is made, and a 503 is returned with a retry header.
    /// - After waiting for the specified time, the manager tries again and gets a 500, with another retry header.
    /// - After waiting for the specified time, the manager tries again and gets a 401, indicating it should
    ///   try to refresh its API token.
    /// - When the manager tries to do this, it gets a 429, with a retry header.
    /// - After waiting for the specified time, the manager tries again and gets told that its session has
    ///   expired. The manager should stop and wait for the app to restart its session.
    /// - When the app gets around to restarting its session, the session auth endpoint returns a 503 error,
    ///   with a retry header.
    /// - Finally, when it tries again, the response succeeds, the manager hits the token refresh endpoint
    ///   successfully, and tries to refresh the cert... but that returns a 500 without a retry header.
    /// - The next subsequent cert refresh request completes successfully and the refresh manager is done.
    func testRespectOfRetryAfterHeader() {
        let expect = { (s: String) in XCTestExpectation(description: s) }

        let expectations = (
            certRefresh503RetryAfter: expect("cert refresh responds with error 503 + retry after header"),
            certRefresh503ScheduledWork: expect("cert refresh 503 retry-after work is scheduled"),
            certRefresh500RetryAfter: expect("cert refresh responds with error 500 + retry after header"),
            certRefresh500ScheduledWork: expect("cert refresh 500 retry-after work is scheduled"),
            certRefresh401TokenRefresh: expect("cert refresh responds with error 401 (token refresh)"),
            tokenRefresh429RetryAfter: expect("token refresh responds with error 429 (too many requests) + retry after header"),
            tokenRefresh429ScheduledWork: expect("token refresh 429 retry-after work is scheduled"),
            tokenRefresh422SessionExpired: expect("token refresh responds with error 422 (session expired)"),
            sessionAuth503RetryAfter: expect("session auth responds with error 503 + retry after header"),
            sessionAuth503ScheduledWork: expect("session auth 503 retry-after work is scheduled"),
            sessionAuthSuccessful: expect("successful session auth request"),
            sessionAuthSuccessfulManagerRestart: expect("manager restart after successful session auth"),
            sessionAuthSuccessfulTimerSchedule: expect("manager restart to result in timer reinit"),
            tokenRefreshSuccessful: expect("token auth to complete successfully"),
            certRefresh503NoRetryAfter: expect("cert refresh responds with error 503 + *no* retry after header"),
            certRefresh503NoRetryScheduledWork: expect("cert refresh 503 no retry-after work is scheduled"),
            certRefreshSuccessful: expect("successful cert refresh request")
        )

        let certRefreshError503WithRetryAfter = mockEndpoint(CertificateRefreshRequest.self,
                                                             apiFailure: .serviceUnavailable,
                                                             responseHeaders: [.retryAfter: "30"],
                                                             expectationToFulfill: expectations.certRefresh503RetryAfter)

        let certRefreshError500WithRetryAfter = mockEndpoint(CertificateRefreshRequest.self,
                                                             apiFailure: .internalError,
                                                             responseHeaders: [.retryAfter: "60"],
                                                             expectationToFulfill: expectations.certRefresh500RetryAfter)

        let certRefresh401ToForceTokenRefresh = mockEndpoint(CertificateRefreshRequest.self,
                                                             apiFailure: .tokenExpired,
                                                             expectationToFulfill: expectations.certRefresh401TokenRefresh)

        let tokenRefreshError429WithRetryAfter = mockEndpoint(TokenRefreshRequest.self,
                                                              apiFailure: .tooManyRequests,
                                                              responseHeaders: [.retryAfter: "90"],
                                                              expectationToFulfill: expectations.tokenRefresh429RetryAfter)

        let tokenRefreshWithError422 = mockEndpoint(TokenRefreshRequest.self,
                                                    apiFailure: .sessionExpired,
                                                    expectationToFulfill: expectations.tokenRefresh422SessionExpired)

        let sessionAuthError503WithRetryAfter = mockEndpoint(SessionAuthRequest.self,
                                                             apiFailure: .serviceUnavailable,
                                                             responseHeaders: [.retryAfter: "120"],
                                                             expectationToFulfill: expectations.sessionAuth503RetryAfter)

        let successfulSessionAuth = mockEndpoint(SessionAuthRequest.self,
                                                 result: .success([:]),
                                                 expectationToFulfill: expectations.sessionAuthSuccessful)

        let successfulTokenRefresh = mockEndpoint(TokenRefreshRequest.self,
                                                  result: .success([:]),
                                                  expectationToFulfill: expectations.tokenRefreshSuccessful)

        let certRefreshError503NoRetryAfter = mockEndpoint(CertificateRefreshRequest.self,
                                                           apiFailure: .serviceUnavailable,
                                                           expectationToFulfill: expectations.certRefresh503NoRetryAfter)

        let successfulCertRefresh = mockEndpoint(CertificateRefreshRequest.self,
                                                 result: .success([:]),
                                                 expectationToFulfill: expectations.certRefreshSuccessful)

        // To make testing easier, set jitter to 0.
        let oldJitterRate = ExtensionAPIService.retryAfterJitterRate
        ExtensionAPIService.retryAfterJitterRate = 0

        let oldJitterDefault = ExtensionAPIService.defaultJitterMaxInSeconds
        ExtensionAPIService.defaultJitterMaxInSeconds = 0

        // immediately run the first timer added.
        timerFactory.timerWasAdded = {
            self.timerFactory.runRepeatingTimers()
        }

        // first cert refresh attempt returns 503 + retry after
        do {
            certRefreshCallback = certRefreshError503WithRetryAfter

            timerFactory.workWasScheduled = {
                expectations.certRefresh503ScheduledWork.fulfill()
            }

            // start the first request.
            manager.start { }

            wait(for: [expectations.certRefresh503RetryAfter, expectations.certRefresh503ScheduledWork], timeout: expectationTimeout)
            guard let scheduledWork = timerFactory.scheduledWork.first else {
                XCTFail("No scheduled work item found")
                return
            }

            XCTAssertEqual(scheduledWork.seconds, 30, "Expected refresh manager to respect 30-second retry-after header")
        }

        // second cert refresh attempt returns 500 + retry after
        do {
            certRefreshCallback = certRefreshError500WithRetryAfter

            timerFactory.workWasScheduled = {
                expectations.certRefresh500ScheduledWork.fulfill()
            }

            // run the work scheduled from the last "do" block.
            timerFactory.runAllScheduledWork()

            wait(for: [expectations.certRefresh500RetryAfter, expectations.certRefresh500ScheduledWork], timeout: expectationTimeout)
            guard let scheduledWork = timerFactory.scheduledWork.first else {
                XCTFail("No scheduled work item found")
                return
            }

            XCTAssertEqual(scheduledWork.seconds, 60, "Expected refresh manager to respect 60-second retry-after header")
        }

        // third cert refresh attempt returns 401, then token refresh endpoint returns 429 + retry after
        do {
            certRefreshCallback = certRefresh401ToForceTokenRefresh
            tokenRefreshCallback = tokenRefreshError429WithRetryAfter

            timerFactory.workWasScheduled = {
                expectations.tokenRefresh429ScheduledWork.fulfill()
            }

            // run the work scheduled from the last "do" block.
            timerFactory.runAllScheduledWork()
            wait(for: [expectations.tokenRefresh429RetryAfter, expectations.tokenRefresh429ScheduledWork], timeout: expectationTimeout)

            guard let scheduledWork = timerFactory.scheduledWork.first else {
                XCTFail("No scheduled work item found")
                return
            }

            XCTAssertEqual(scheduledWork.seconds, 90, "Expected refresh manager to respect 90-second retry-after header")
        }

        // second token refresh attempt returns 422. manager should stop & wait for app to perform session auth
        do {
            certRefreshCallback = failCallback
            tokenRefreshCallback = tokenRefreshWithError422

            timerFactory.workWasScheduled = {
                XCTFail("Should not schedule work")
            }

            timerFactory.timerWasAdded = {
                XCTFail("Should not add timer")
            }

            // run the work scheduled from the last "do" block.
            timerFactory.runAllScheduledWork()

            wait(for: [expectations.tokenRefresh422SessionExpired], timeout: expectationTimeout)
            timerFactory.lastQueueWorkWasScheduledOn?.sync {
                XCTAssertTrue(apiService.sessionExpired)
            }

            // note: "timer was added" should still fail here, because the manager shouldn't restart until
            // the session auth completes successfully.
            timerFactory.workWasScheduled = {
                expectations.sessionAuth503ScheduledWork.fulfill()
            }

            sessionAuthCallback = sessionAuthError503WithRetryAfter
            manager.newSession(withSelector: Self.sessionSelector) { result in
                if case let .failure(error) = result {
                    XCTFail("Should not return error here. This should be called with success when the " +
                            "completion handler is rescheduled and returns successfully (got '\(error)')")
                }
                // note: this won't be fulfilled until three blocks down, when the cert retry succeeds
                expectations.sessionAuthSuccessfulManagerRestart.fulfill()
            }

            // Remove manager's existing timer, since it won't be restarted after auth fails due to retry error,
            // and we will want to check that it's added when auth eventually succeeds
            timerFactory.repeatingTimers = []

            wait(for: [expectations.sessionAuth503RetryAfter, expectations.sessionAuth503ScheduledWork], timeout: expectationTimeout)

            guard let scheduledWork = timerFactory.scheduledWork.first else {
                XCTFail("No scheduled work item found")
                return
            }

            XCTAssertEqual(scheduledWork.seconds, 120, "Expected refresh manager to respect 120-second retry-after header")
        }

        // second session auth attempt returns success, resulting in a successful token refresh,
        // but the second-to-last cert refresh attempt results in error 503, without a retry-after header.
        do {
            sessionAuthCallback = successfulSessionAuth
            tokenRefreshCallback = successfulTokenRefresh
            certRefreshCallback = certRefreshError503NoRetryAfter

            timerFactory.timerWasAdded = {
                XCTFail("Shouldn't add any timers here")
            }

            self.timerFactory.workWasScheduled = {
                expectations.certRefresh503NoRetryScheduledWork.fulfill()
            }

            timerFactory.runAllScheduledWork()

            wait(for: [expectations.sessionAuthSuccessful,
                       expectations.tokenRefreshSuccessful,
                       expectations.certRefresh503NoRetryAfter,
                       expectations.certRefresh503NoRetryScheduledWork], timeout: expectationTimeout)

            guard let scheduledWork = timerFactory.scheduledWork.first else {
                XCTFail("No scheduled work item found")
                return
            }

            XCTAssertEqual(scheduledWork.seconds, 30, "Expected refresh manager to default to 30-second retry-after interval")
        }

        // finally, last cert refresh request ends in success.
        do {
            certRefreshCallback = successfulCertRefresh

            self.timerFactory.runAllScheduledWork()

            wait(for: [expectations.certRefreshSuccessful,
                       expectations.sessionAuthSuccessfulManagerRestart], timeout: expectationTimeout)
        }

        ExtensionAPIService.retryAfterJitterRate = oldJitterRate
        ExtensionAPIService.defaultJitterMaxInSeconds = oldJitterDefault
    }

    /// Simulates a network timeout and checks that the request is rescheduled.
    func testRetryHappensAfterNetworkTimeout() {
        let expectations = (
            certRefreshRequest: XCTestExpectation(description: "Cert refresh request"),
            certRefreshReschedule: XCTestExpectation(description: "Cert refresh request was rescheduled")
        )

        certRefreshCallback = { request, completionHandler in
            completionHandler(nil, nil, POSIXError(.ETIMEDOUT))
            expectations.certRefreshRequest.fulfill()
        }

        timerFactory.timerWasAdded = {
            self.timerFactory.runRepeatingTimers()
        }

        timerFactory.workWasScheduled = {
            expectations.certRefreshReschedule.fulfill()
        }

        manager.start { }

        wait(for: [expectations.certRefreshRequest, expectations.certRefreshReschedule], timeout: expectationTimeout)

        guard let scheduledWork = timerFactory.scheduledWork.first else {
            XCTFail("No scheduled work item found")
            return
        }

        XCTAssertEqual(scheduledWork.seconds, 30, "Expected refresh manager to default to 30-second retry-after interval")
    }

    /// An operation begins, gets a network timeout, schedules a retry, wakes up, and should realize it's cancelled.
    func testManagerStopAfterSchedulingRetryDueToNetworkTimeoutResultsInOperationBeingCancelled() {
        let expectations = (
            certRefreshRequest: XCTestExpectation(description: "Cert refresh request"),
            certRefreshReschedule: XCTestExpectation(description: "Cert refresh request was rescheduled"),
            certRefreshCancelled: XCTestExpectation(description: "Cert refresh should be cancelled")
        )

        certRefreshCallback = { request, completionHandler in
            completionHandler(nil, nil, POSIXError(.ETIMEDOUT))
            expectations.certRefreshRequest.fulfill()
        }

        timerFactory.workWasScheduled = {
            expectations.certRefreshReschedule.fulfill()
        }

        manager.start { }
        manager.checkRefreshCertificateNow(features: authenticationStorage.features!) { result in
            guard case let .failure(error) = result else {
                XCTFail("Expected cancelled error but got success")
                return
            }

            guard case .cancelled = error else {
                XCTFail("Expected cancelled error but got \(error)")
                return
            }
            expectations.certRefreshCancelled.fulfill()
        }

        wait(for: [expectations.certRefreshRequest, expectations.certRefreshReschedule], timeout: expectationTimeout)

        manager.stop {
            self.certRefreshCallback = { _, _ in
                XCTFail("Shouldn't have tried to refresh; operation should have been cancelled")
            }
        }

        timerFactory.runAllScheduledWork()
        wait(for: [expectations.certRefreshCancelled], timeout: expectationTimeout)
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
        self.certificate = fakeData[\.certificate] as? String ?? "certificate"
        self.validUntil = fakeData[\.validUntil] as? Date ?? Date()
        self.refreshTime = fakeData[\.refreshTime] as? Date ?? Date()
    }
}

extension CertificateRefreshRequest: MockableRequest {
}

extension TokenRefreshRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.accessToken = fakeData[\.accessToken] as? String ?? "accessToken"
        self.refreshToken = fakeData[\.refreshToken] as? String ?? "refreshToken"
        self.expiresIn = fakeData[\.expiresIn] as? TimeInterval ?? 15
    }
}

extension TokenRefreshRequest: MockableRequest {
}

extension SessionAuthRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.uid = fakeData[\.uid] as? String ?? "uid"
        self.refreshToken = fakeData[\.refreshToken] as? String ?? "refreshToken"
    }
}

extension SessionAuthRequest: MockableRequest {
}
