//
//  Created on 2022-10-05.
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

// swiftlint:disable:file function_body_length
class CertificateRefreshTests: ExtensionAPIServiceTestCase {
    var manager: ExtensionCertificateRefreshManager!

    override func setUp() async throws {
        try await super.setUp()

        self.manager = ExtensionCertificateRefreshManager(apiService: apiService,
                                                          timerFactory: timerFactory,
                                                          vpnAuthenticationStorage: authenticationStorage,
                                                          keychain: keychain)
    }

    /// We have to use this because the VPNConnectionFeatures in the request parameters has a decode function that is
    /// meant for local storage, not for decoding the request sent to the API. This can be removed once the
    /// CertificateRefreshForceRenew feature flag isn't needed anymore.
    struct RenewParameter: Decodable {
        let renew: Bool
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

        let callback = mockEndpoint(
            CertificateRefreshRequest.self,
            result: .success([\.certificate: testValues.cert,
                              \.refreshTime: testValues.refreshTime,
                              \.validUntil: testValues.validUntil]),
            expectationToFulfill: expectations.certRefresh
        )

        // We can remove this part of the test once the CertificateRefreshForceRenew feature flag is no longer used
        forceRenew = true

        certRefreshCallback = { request, completionHandler in
            guard let body = request.httpBody else {
                XCTFail("Request should have had a body")
                return
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .decapitaliseFirstLetter
            guard let params = try? decoder.decode(RenewParameter.self, from: body) else {
                XCTFail("Couldn't decode renew parameter")
                return
            }

            XCTAssert(params.renew)

            callback(request, completionHandler)
        }

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

        manager.newSession(withSelector: Self.sessionSelector, sessionCookie: Self.sessionCookie) { result in
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
        XCTAssert(features.equals(other: authenticationStorage.features, safeModeFeatureEnabled: true))
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

        let oldJitterDefault = ExtensionAPIService.intervals.defaultJitterMax
        ExtensionAPIService.intervals.defaultJitterMax = 0

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

            XCTAssertEqual(scheduledWork.interval, .seconds(30), "Expected refresh manager to respect 30-second retry-after header")
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

            XCTAssertEqual(scheduledWork.interval, .seconds(60), "Expected refresh manager to respect 60-second retry-after header")
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

            XCTAssertEqual(scheduledWork.interval, .seconds(90), "Expected refresh manager to respect 90-second retry-after header")
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
            manager.newSession(withSelector: Self.sessionSelector, sessionCookie: Self.sessionCookie) { result in
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

            XCTAssertEqual(scheduledWork.interval, .seconds(120), "Expected refresh manager to respect 120-second retry-after header")
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

            XCTAssertEqual(scheduledWork.interval, .seconds(30), "Expected refresh manager to default to 30-second retry-after interval")
        }

        // finally, last cert refresh request ends in success.
        do {
            certRefreshCallback = successfulCertRefresh

            self.timerFactory.runAllScheduledWork()

            wait(for: [expectations.certRefreshSuccessful,
                       expectations.sessionAuthSuccessfulManagerRestart], timeout: expectationTimeout)
        }

        ExtensionAPIService.retryAfterJitterRate = oldJitterRate
        ExtensionAPIService.intervals.defaultJitterMax = oldJitterDefault
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

        XCTAssertEqual(scheduledWork.interval, .seconds(5), "Expected refresh manager to default to 30-second retry-after interval")
    }

    /// An operation begins, gets a network timeout, schedules a retry, wakes up, and should realize it's cancelled.
    func testManagerStopAfterSchedulingRetryDueToNetworkTimeoutResultsInOperationBeingCancelled() {
        let expectations = (
            certRefreshRequest: XCTestExpectation(description: "Cert refresh request"),
            certRefreshReschedule: XCTestExpectation(description: "Cert refresh request was rescheduled"),
            certRefreshCancelled: XCTestExpectation(description: "Cert refresh should be cancelled"),
            managerStop: XCTestExpectation(description: "Manager should stop")
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
            expectations.managerStop.fulfill()
            self.timerFactory.runAllScheduledWork()
        }
        wait(for: [expectations.certRefreshCancelled, expectations.managerStop], timeout: expectationTimeout, enforceOrder: true)
    }

    /// The network extension should use the main app's credentials if it can't find any of its own in the keychain.
    /// Furthermore, if the network extension encounters an "invalid api token" error, it should only attempt to
    /// refresh the token if the main app has not yet sent it a message.
    func testExtensionUsesMainAppCredentialsIfNoExtensionCredsInKeychain() {
        let expectations = (
            firstCertRefresh: XCTestExpectation(description: "first cert refresh"),
            secondCertRefresh: XCTestExpectation(description: "second cert refresh"),
            thirdCertRefresh: XCTestExpectation(description: "third cert refresh"),
            tokenRefresh: XCTestExpectation(description: "token refresh"),
            sessionExpiredResult: XCTestExpectation(description: "session expired result"),
            credentialsStored: XCTestExpectation(description: "credentials stored"),
            managerStart: XCTestExpectation(description: "manager did start")
        )

        let testData = (
            updatedAccessToken: "new access token",
            updatedRefreshToken: "new refresh token"
        )

        keychain.credentials = [
            .mainApp: .init(username: "me",
                            accessToken: "access",
                            refreshToken: "refresh",
                            sessionId: "session",
                            userId: "user",
                            scopes: [])
        ]

        var numCertRequests = 0
        certRefreshCallback = { request, completionHandler in
            switch numCertRequests {
            // initial request, which should return an invalid token.
            case 0:
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-pm-uid"), "session")
                fallthrough
            // the third request should respond with "invalid token" after the app has checked in with the extension.
            case 2:
                let expectation = numCertRequests == 0 ? expectations.firstCertRefresh : expectations.thirdCertRefresh
                let callback = self.mockEndpoint(CertificateRefreshRequest.self,
                                                 apiFailure: .tokenExpired,
                                                 expectationToFulfill: expectation)
                callback(request, completionHandler)
            // the request after the first one, which should provide a valid access token.
            case 1:
                let callback = self.mockEndpoint(CertificateRefreshRequest.self,
                                                 result: .success([:]),
                                                 expectationToFulfill: expectations.secondCertRefresh)
                callback(request, completionHandler)
            default:
                DispatchQueue.main.async {
                    XCTFail("Should perform at most 3 cert refresh requests (performed \(numCertRequests + 1))")
                }
            }
            numCertRequests += 1
        }

        tokenRefreshCallback = mockEndpoint(TokenRefreshRequest.self,
                                            result: .success([
                                                \.accessToken: testData.updatedAccessToken,
                                                \.refreshToken: testData.updatedRefreshToken,
                                            ]),
                                            expectationToFulfill: expectations.tokenRefresh)

        timerFactory.timerWasAdded = {
            self.timerFactory.runRepeatingTimers()
        }

        keychain.credentialsWereStored = {
            expectations.credentialsStored.fulfill()
        }

        manager.start {
            expectations.managerStart.fulfill()
        }

        // Sequence of operations: manager starts, then checks certificate, gets token refresh error,
        // tries to refresh token, succeeds & stores credentials, then asks successfully for second cert refresh.
        wait(for: [expectations.managerStart,
                   expectations.firstCertRefresh,
                   expectations.tokenRefresh,
                   expectations.credentialsStored,
                   expectations.secondCertRefresh], timeout: 10)

        // The new credentials should be stored in the main app's keychain, not in the extension's
        XCTAssertEqual(keychain.credentials[.mainApp]?.accessToken, testData.updatedAccessToken)
        XCTAssertEqual(keychain.credentials[.mainApp]?.refreshToken, testData.updatedRefreshToken)

        let callback = certRefreshCallback
        certRefreshCallback = failCallback // shouldn't try to refresh for next request

        // initiate a request on behalf of the app. refresh manager should take this to mean that
        // the app is alive and well, and should be able to create a new session for it, so it will
        // reply saying that its session has expired.
        manager.checkRefreshCertificateNow(features: nil, userInitiated: true) { result in
            guard case let .failure(error) = result else {
                XCTFail("Should have gotten session expired error, but got success")
                return
            }

            guard case .sessionExpiredOrMissing = error else {
                XCTFail("Should have gotten session expired but got \(error)")
                return
            }
            expectations.sessionExpiredResult.fulfill()
        }

        wait(for: [expectations.sessionExpiredResult], timeout: 10)

        certRefreshCallback = callback
        tokenRefreshCallback = { _, _ in
            XCTFail("Extension should not try to refresh token if the app has checked in.")
        }

        // Run another certificate refresh in the background. Should get a token refresh error, but should
        // not try to refresh the token, since the app has already checked in.
        timerFactory.runRepeatingTimers()
        wait(for: [expectations.thirdCertRefresh], timeout: 10)
    }

    func testExtensionDoesNotHitAPIWhenUsingExpiredMainAppSession() {
        let expectations = (
            firstCertRefresh: XCTestExpectation(description: "first certificate refresh"),
            authTokenRefresh: XCTestExpectation(description: "first auth token refresh"),
            sessionExpiredResult: (1...3).map { XCTestExpectation(description: "session expiry result #\($0)") }
        )

        keychain.credentials = [
            .mainApp: .init(username: "me",
                            accessToken: "access",
                            refreshToken: "refresh",
                            sessionId: "session",
                            userId: "user",
                            scopes: [])
        ]

        certRefreshCallback = mockEndpoint(CertificateRefreshRequest.self,
                                           apiFailure: .tokenExpired,
                                           expectationToFulfill: expectations.firstCertRefresh)
        tokenRefreshCallback = mockEndpoint(TokenRefreshRequest.self,
                                            apiFailure: .sessionExpired,
                                            expectationToFulfill: expectations.authTokenRefresh)

        manager.start { }

        manager.checkRefreshCertificateNow(features: nil) { result in
            defer { expectations.sessionExpiredResult[0].fulfill() }

            XCTAssertTrue(self.apiService.sessionExpired)

            guard case let .failure(error) = result, case .sessionExpiredOrMissing = error else {
                XCTFail("Request should have failed with expired session")
                return
            }
        }

        wait(for: [expectations.firstCertRefresh,
                   expectations.authTokenRefresh,
                   expectations.sessionExpiredResult[0]], timeout: expectationTimeout)

        // we shouldn't hit the API at all here
        certRefreshCallback = failCallback
        tokenRefreshCallback = failCallback
        sessionAuthCallback = failCallback

        manager.checkRefreshCertificateNow(features: nil) { result in
            defer { expectations.sessionExpiredResult[1].fulfill() }

            XCTAssertTrue(self.apiService.sessionExpired)

            guard case let .failure(error) = result, case .sessionExpiredOrMissing = error else {
                XCTFail("Request should have failed with expired session")
                return
            }
        }

        wait(for: [expectations.sessionExpiredResult[1]], timeout: expectationTimeout)

        manager.checkRefreshCertificateNow(features: nil, userInitiated: true, forceRefreshDueToExpiredSession: false) { result in
            defer { expectations.sessionExpiredResult[2].fulfill() }

            XCTAssertTrue(self.apiService.sessionExpired)

            guard case let .failure(error) = result, case .sessionExpiredOrMissing = error else {
                XCTFail("Request should have failed with expired session")
                return
            }
        }

        wait(for: [expectations.sessionExpiredResult[2]], timeout: expectationTimeout)
    }

    // Network operations should be cancelled on manager deinit, because
    // operations use unowned manager. If this is not done, this text will crash with SIGBART.
    func testDeinitDuringRequestDoesntCrash() {
        let willStop = DispatchGroup()
        let didStop = XCTestExpectation(description: "Wait for certificate refresh request")
        let didRefresh = XCTestExpectation(description: "Did refresh operation (even though it may have timed out)")
        let expectationTimeout: TimeInterval = 5

        timerFactory.workWasScheduled = { [weak self] in
            let second: Double = 1000000
            usleep(UInt32(0.5 * second))

            self?.timerFactory.runAllScheduledWork()
        }

        certRefreshCallback = { request, completion in
            willStop.wait()

            completion(nil, nil, POSIXError(.ETIMEDOUT))
        }

        willStop.enter()
        manager.start {
            self.manager.checkRefreshCertificateNow(features: self.authenticationStorage.features!) { result in
                guard case let .failure(error) = result else {
                    XCTFail("Expected error but got \(result)")
                    return
                }

                guard case CertificateRefreshError.cancelled = error else {
                    XCTFail("Expected cancelled error but got \(error)")
                    return
                }

                didRefresh.fulfill()
            }

            self.manager.stop {
                // Unsetting manager leads to some crashes
                self.manager = nil

                didStop.fulfill()
            }

            willStop.leave()
        }
        wait(for: [didRefresh, didStop], timeout: expectationTimeout, enforceOrder: true)
    }

    /// Suspending and resuming a manager (not stopping) should not prevent future certificate refreshes operations from starting
    func testSuspendingManagerDoesNotBlockFutureOperations() {
        let expectations = (
            managerSuspended: XCTestExpectation(description: "Manager should be suspended"),
            managerStarted: XCTestExpectation(),
            managerResumed: XCTestExpectation(),
            certRefreshRequest: XCTestExpectation(description: "Cert refresh request")
        )

        certRefreshCallback = { (_, _) in
            XCTFail("Shouldn't try to refresh before refresh is requested")
        }

        manager.start {
            expectations.managerStarted.fulfill()
            self.manager.suspend {
                expectations.managerSuspended.fulfill()
                self.manager.start {
                    expectations.managerResumed.fulfill()
                }
            }
        }

        wait(for: [expectations.managerStarted, expectations.managerSuspended, expectations.managerResumed], timeout: expectationTimeout, enforceOrder: true)

        certRefreshCallback = { (_, _) in
            expectations.certRefreshRequest.fulfill()
        }

        manager.checkRefreshCertificateNow(features: authenticationStorage.features!) { _ in }

        wait(for: [expectations.certRefreshRequest], timeout: expectationTimeout)
    }
}
