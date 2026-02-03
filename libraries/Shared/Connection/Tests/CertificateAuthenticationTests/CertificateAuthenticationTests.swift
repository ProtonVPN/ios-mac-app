//
//  Created on 24/06/2024.
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

@testable import CertificateAuthentication
import ComposableArchitecture
@testable import CoreConnection
import CoreConnectionTestSupport
import struct Domain.VPNConnectionFeatures
import Foundation
import VPNShared
import VPNSharedTesting
import XCTest

final class CertificateAuthenticationTests: XCTestCase {
    /// If we don't have keys at the point where we are trying to load our certificate to connect to local agent, then
    /// the tunnel has already been started. If we generate keys at this point, then the certificate won't match the
    /// private key the tunnel was started/configured with. We should abort the connection and the keys will be
    /// generated on the next attempt.
    @MainActor
    func testAbortsConnectionIfKeysAreMissing() async {
        let storageMock = VpnAuthenticationStorage.testStorage()
        let now = Date()

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.vpnKeysGenerator = .init(generateKeys: {
                // Generating keys won't do us any good unless we make sure to reconfigure and restart the tunnel.
                XCTFail("We shouldn't generate keys during certificate authentication")
                return .mock()
            })
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }

        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.keysMissing) {
            $0 = .failed(.keysMissing)
        }
        await store.receive(\.loadingFinished.failure)
    }

    /// This asserts that we do unnecessarily push a session selector, or attempt to refresh the certificate
    @MainActor
    func testLoadsExistingCertificateIfNotExpired() async {
        let now = Date()
        let clock = TestClock()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let mockStorage = VpnAuthenticationStorage.testStorage(
            keys: mockKeys,
            certificate: mockCertificate,
            features: .mock
        )

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: unimplemented("Unexpected local refresh"),
                refreshCertificate: unimplemented("Unexpected certificate refresh"),
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: .mock))
        }
        await store.receive(\.loadingFinished.success)

        await store.send(.cancelRefreshes) // cancel refresh queued for when the current certificate expires
    }

    /// This asserts that we refresh the certificate if our stored certificate is valid, but features have since changed
    @MainActor
    func testRefreshesValidCertificateWithOldFeatures() async {
        let now = Date()
        let clock = TestClock()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let storedFeatures = VPNConnectionFeatures(
            netshield: .off,
            vpnAccelerator: false,
            bouncing: "0",
            natType: .moderateNAT,
            safeMode: false,
            portForwarding: false
        )
        let newFeatures = VPNConnectionFeatures(
            netshield: .level2,
            vpnAccelerator: true,
            bouncing: "1",
            natType: .strictNAT,
            safeMode: true,
            portForwarding: false
        )

        let mockStorage = VpnAuthenticationStorage.testStorage(
            keys: mockKeys,
            certificate: mockCertificate,
            features: storedFeatures
        )

        let certRefreshRequested = XCTestExpectation(description: "Feature should request refresh using the client")

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { newFeatures }
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: unimplemented("Unexpected local refresh"),
                refreshCertificate: { features in
                    certRefreshRequested.fulfill()
                    XCTAssertEqual(features, newFeatures, "Certificate should be refreshed with new features")
                    mockStorage.storeCertificateWithFeatures(.init(certificate: mockCertificate, features: features))
                },
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: newFeatures))
        }
        await store.receive(\.loadingFinished.success)
        await fulfillment(of: [certRefreshRequested], timeout: 0)

        await store.send(.cancelRefreshes) // cancel refresh queued for when the current certificate expires
    }

    @MainActor
    func testRefreshesMissingOrExpiredCertificateWithFeatures() async {
        let now = Date()
        let clock = TestClock()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let mockStorage = VpnAuthenticationStorage.testStorage(keys: mockKeys)

        let expectedFeatures = VPNConnectionFeatures(
            netshield: .level1,
            vpnAccelerator: false,
            bouncing: nil,
            natType: .strictNAT,
            safeMode: nil,
            portForwarding: false
        )
        let certRefreshRequested = XCTestExpectation(description: "Feature should request refresh using the client")

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { expectedFeatures }
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: unimplemented("Unexpected local refresh"),
                refreshCertificate: { features in
                    certRefreshRequested.fulfill()
                    XCTAssertEqual(features, expectedFeatures, "Certificate should be refreshed with current features")
                    mockStorage.storeCertificateWithFeatures(.init(certificate: mockCertificate, features: features))
                },
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateMissing)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: expectedFeatures))
        }
        await store.receive(\.loadingFinished.success)
        await fulfillment(of: [certRefreshRequested], timeout: 0)

        await store.send(.cancelRefreshes) // cancel refresh queued for when the current certificate expires
    }

    /// Similar to `testRefreshesValidCertificateWithOldFeatures`. In this case, the certificate is comes from memory
    /// instead of being loaded from storage.
    @MainActor
    func testRefreshesValidCachedCertificateWithOldFeatures() async {
        let now = Date()
        let clock = TestClock()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let mockStorage = VpnAuthenticationStorage.testStorage(
            keys: mockKeys,
            certificate: mockCertificate
        )

        let newFeatures = VPNConnectionFeatures(
            netshield: .level2,
            vpnAccelerator: true,
            bouncing: "1",
            natType: .strictNAT,
            safeMode: true,
            portForwarding: true
        )
        let certRefreshRequested = XCTestExpectation(description: "Feature should request refresh using the client")

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { newFeatures }
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: unimplemented("Unexpected local refresh"),
                refreshCertificate: { features in
                    certRefreshRequested.fulfill()
                    XCTAssertEqual(features, newFeatures, "Certificate should be refreshed with current features")
                    mockStorage.storeCertificateWithFeatures(.init(certificate: mockCertificate, features: features))
                },
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        // Our cached certificate is still valid, but should be refreshed because features don't match our current settings
        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        // We should load from storage just in case we somehow have an old certificate
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded)
        // But the certificate should be immediately refreshed because the features are still mismatched
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: newFeatures))
        }
        await store.receive(\.loadingFinished.success)
        await fulfillment(of: [certRefreshRequested], timeout: 0)

        await store.send(.cancelRefreshes) // cancel refresh queued for when the current certificate expires
    }

    @MainActor
    func testEntersFailedStateIfExtensionLiesAboutRefreshingCertificate() async {
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockStorage = VpnAuthenticationStorage.testStorage(keys: mockKeys)

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.vpnAuthenticationStorage = mockStorage
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: unimplemented("Unexpected local refresh"),
                refreshCertificate: { _ in }, // Extension doesn't throw an error but doesn't actually update the certificate
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateMissing)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateMissing) {
            $0 = .failed(.certificateMissing)
        }
        await store.receive(\.loadingFinished.failure)
    }

    @MainActor
    func testPurgesKeysAndEntersFailedStateIfExtensionReportsRequiringKeyRegeneration() async {
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        var mockStorage = VpnAuthenticationStorage.testStorage(keys: mockKeys)

        let keysDeleted = XCTestExpectation(description: "Keys should have been deleted")
        mockStorage.deleteKeys = { keysDeleted.fulfill() }

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.vpnAuthenticationStorage = mockStorage
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: unimplemented("Unexpected local refresh"),
                refreshCertificate: { _ throws(CertificateRefreshError) in throw .requiresNewKeys },
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateMissing)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.failure.requiresNewKeys) {
            $0 = .failed(.refreshFailed(.requiresNewKeys))
        }
        await store.receive(\.loadingFinished.failure)
        await fulfillment(of: [keysDeleted], timeout: 0)
    }

    @MainActor
    func testReloadsRefreshedCertificateAfterExpiry() async {
        let clock = TestClock()
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let nextWeek = tomorrow.addingTimeInterval(.days(6))

        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let existingCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let mockStorage = VpnAuthenticationStorage.testStorage(
            keys: mockKeys,
            certificate: existingCertificate,
            features: .mock
        )

        let keys = VPNKeys(fromLegacyKeys: mockKeys)
        let authData = FullAuthenticationData(keys: keys, certificate: existingCertificate, features: .mock)

        let store = TestStore(initialState: .loading(shouldRefreshIfNecessary: false)) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
        }

        // Simulate first/existing certificate being loaded
        await store.send(.loadingFromStorageFinished(.loaded(authData))) {
            $0 = .loaded(authData)
        }
        await store.receive(\.loadingFinished.success)

        // Advance clock past the refresh time of the loaded certificate
        await clock.advance(by: .hours(20))

        // Around this time, the extension should refresh the certificate in the background
        // Let's model the extension has successfully refreshing the certificate and storing it in the keychain
        let refreshedCertificate = VpnCertificate(certificate: "5678", validUntil: nextWeek, refreshTime: nextWeek)
        let refreshedAuthData = FullAuthenticationData(keys: keys, certificate: refreshedCertificate, features: .mock)
        mockStorage.storeCertificate(refreshedCertificate)

        // Fast forward until the certificate expiry
        store.dependencies.date = .constant(tomorrow)
        await clock.advance(by: .hours(4))

        await store.receive(\.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(refreshedAuthData)
        }
        await store.receive(\.loadingFinished.success)

        await store.send(.cancelRefreshes) // cancel refresh queued for when the current certificate expires
    }

    /// This test is similar to the previous `testReloadsRefreshedCertificateAfterExpiry`, except when we go to load
    /// the certificate from the keychain, we find that the extension hasn't been able to refresh it yet.
    /// In the off-chance the extension hasn't been able to refresh the certificate in the background, we should load
    /// the expiring certificate and proceed with certificate refresh as normal
    @MainActor
    func testPromptsExtensionForCertificateRefreshAfterExpiry() async {
        let clock = TestClock()
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let nextWeek = tomorrow.addingTimeInterval(.days(6))

        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let existingCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let mockStorage = VpnAuthenticationStorage.testStorage(
            keys: mockKeys,
            certificate: existingCertificate,
            features: .mock
        )

        let keys = VPNKeys(fromLegacyKeys: mockKeys)
        let authData = FullAuthenticationData(keys: keys, certificate: existingCertificate, features: .mock)

        let refreshedCertificate = VpnCertificate(certificate: "5678", validUntil: nextWeek, refreshTime: nextWeek)
        let refreshedAuthData = FullAuthenticationData(keys: keys, certificate: refreshedCertificate, features: .mock)

        let store = TestStore(initialState: .loading(shouldRefreshIfNecessary: false)) {
            CertificateAuthenticationFeature()
                ._printChanges()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.vpnAuthenticationStorage = mockStorage
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: unimplemented("Unexpected local refresh"),
                refreshCertificate: { _ in mockStorage.storeCertificate(refreshedCertificate) }, // Instant successful refresh
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        // Simulate first/existing certificate being loaded
        await store.send(.loadingFromStorageFinished(.loaded(authData))) {
            $0 = .loaded(authData)
        }
        await store.receive(\.loadingFinished.success)

        // Advance clock past the refresh & expiry time of the loaded certificate
        store.dependencies.date = .constant(tomorrow)
        await clock.advance(by: .hours(24))

        // Around this time, the extension should refresh the certificate in the background
        // In this test, we will see what happens if the extension has not yet been able to refesh the certificate

        await store.receive(\.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateExpired)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }

        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(refreshedAuthData)
        }
        await store.receive(\.loadingFinished.success)

        await store.send(.cancelRefreshes) // cancel refresh queued for when the current certificate expires
    }
}
