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

import Foundation
import XCTest
import ComposableArchitecture
import struct Domain.VPNConnectionFeatures
import VPNShared
import VPNSharedTesting
@testable import CoreConnection
import CoreConnectionTestSupport
@testable import CertificateAuthentication

final class CertificateAuthenticationTests: XCTestCase {
    /// If we don't have keys at the point where we are trying to load our certificate to connect to local agent, then
    /// the tunnel has already been started. If we generate keys at this point, then the certificate won't match the
    /// private key the tunnel was started/configured with. We should abort the connection and the keys will be
    /// generated on the next attempt.
    @MainActor func testAbortsConnectionIfKeysAreMissing() async {
        let storageMock = MockVpnAuthenticationStorage()
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
            $0 = .failed(.wontRefresh(.keysMissing))
        }
        await store.receive(\.loadingFinished.failure)
    }

    /// This asserts that we do unnecessarily push a session selector, or attempt to refresh the certificate
    @MainActor func testLoadsExistingCertificateIfNotExpired() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let storageMock = MockVpnAuthenticationStorage()
        storageMock.keys = mockKeys
        storageMock.cert = mockCertificate
        storageMock.features = .mock

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.connectionFeatureProvider.connectionFeatures = { .mock }
            $0.certificateRefreshClient = .init(
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
    }

    /// This asserts that we refresh the certificate if our stored certificate is valid, but features have since changed
    @MainActor func testRefreshesValidCertificateWithOldFeatures() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)
        let storedFeatures = VPNConnectionFeatures(netshield: .off, vpnAccelerator: false, bouncing: "0", natType: .moderateNAT, safeMode: false)
        let newFeatures = VPNConnectionFeatures(netshield: .level2, vpnAccelerator: true, bouncing: "1", natType: .strictNAT, safeMode: true)

        let storageMock = MockVpnAuthenticationStorage()
        storageMock.keys = mockKeys
        storageMock.cert = mockCertificate
        storageMock.features = storedFeatures

        let certRefreshRequested = XCTestExpectation(description: "Feature should request refresh using the client")

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.connectionFeatureProvider.connectionFeatures = { newFeatures }
            $0.certificateRefreshClient = .init(
                refreshCertificate: { features in
                    certRefreshRequested.fulfill()
                    XCTAssertEqual(features, newFeatures, "Certificate should be refreshed with new features")
                    storageMock.cert = mockCertificate
                    storageMock.features = features
                    return .ok
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
        await store.receive(\.refreshFinished.success.ok) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: newFeatures))
        }
        await store.receive(\.loadingFinished.success)
        await fulfillment(of: [certRefreshRequested], timeout: 0)
    }

    @MainActor func testRefreshesMissingOrExpiredCertificateWithFeatures() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let storageMock = MockVpnAuthenticationStorage()
        storageMock.keys = mockKeys
        storageMock.cert = nil

        let expectedFeatures = VPNConnectionFeatures(netshield: .level1, vpnAccelerator: false, bouncing: nil, natType: .strictNAT, safeMode: nil)
        let certRefreshRequested = XCTestExpectation(description: "Feature should request refresh using the client")

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.connectionFeatureProvider.connectionFeatures = { expectedFeatures }
            $0.certificateRefreshClient = .init(
                refreshCertificate: { features in
                    certRefreshRequested.fulfill()
                    XCTAssertEqual(features, expectedFeatures, "Certificate should be refreshed with current features")
                    storageMock.cert = mockCertificate
                    storageMock.features = features
                    return .ok
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
        await store.receive(\.refreshFinished.success.ok) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: expectedFeatures))
        }
        await store.receive(\.loadingFinished.success)
        await fulfillment(of: [certRefreshRequested], timeout: 0)
    }

    /// Similar to `testRefreshesValidCertificateWithOldFeatures`. In this case, the certificate is comes from memory
    /// instead of being loaded from storage.
    @MainActor func testRefreshesValidCachedCertificateWithOldFeatures() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let storageMock = MockVpnAuthenticationStorage()
        storageMock.keys = mockKeys
        storageMock.cert = mockCertificate

        let storedFeatures = VPNConnectionFeatures(netshield: .off, vpnAccelerator: false, bouncing: "0", natType: .moderateNAT, safeMode: false)
        let newFeatures = VPNConnectionFeatures(netshield: .level2, vpnAccelerator: true, bouncing: "1", natType: .strictNAT, safeMode: true)
        let certRefreshRequested = XCTestExpectation(description: "Feature should request refresh using the client")

        let loadedAuthenticationData = FullAuthenticationData(
            keys: .init(fromLegacyKeys: mockKeys),
            certificate: mockCertificate,
            features: storedFeatures
        )
        
        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.connectionFeatureProvider.connectionFeatures = { newFeatures }
            $0.certificateRefreshClient = .init(
                refreshCertificate: { features in
                    certRefreshRequested.fulfill()
                    XCTAssertEqual(features, newFeatures, "Certificate should be refreshed with current features")
                    storageMock.cert = mockCertificate
                    storageMock.features = features
                    return .ok
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
        await store.receive(\.refreshFinished.success.ok) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate, features: newFeatures))
        }
        await store.receive(\.loadingFinished.success)
        await fulfillment(of: [certRefreshRequested], timeout: 0)
    }

    @MainActor func testEntersFailedStateIfExtensionLiesAboutRefreshingCertificate() async {
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")

        let storageMock = MockVpnAuthenticationStorage()
        storageMock.keys = mockKeys
        storageMock.cert = nil

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.vpnAuthenticationStorage = storageMock
            $0.certificateRefreshClient = .init(
                refreshCertificate: { _ in .ok }, // Extension responds with .ok but doesn't actually update the certificate
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateMissing)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success.ok) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateMissing) {
            $0 = .failed(.wontRefresh(.certificateMissing))
        }
        await store.receive(\.loadingFinished.failure)
    }

    @MainActor func testPurgesKeysAndEntersFailedStateIfExtensionReportsRequiringKeyRegeneration() async {
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")

        let storageMock = MockVpnAuthenticationStorage()
        storageMock.keys = mockKeys
        storageMock.cert = nil

        let keysDeleted = XCTestExpectation(description: "Keys should have been deleted")
        storageMock.keysDeleted = { keysDeleted.fulfill() }

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.vpnAuthenticationStorage = storageMock
            $0.certificateRefreshClient = .init(
                refreshCertificate: { _ in .requiresNewKeys }, // Extension responds with .ok but doesn't actually update the certificate
                pushSelector: unimplemented("Unexpected session fork + selector push")
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.certificateMissing)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success.requiresNewKeys) {
            $0 = .failed(.wontRefresh(.keysMissing))
        }
        await store.receive(\.loadingFinished.failure)
        await fulfillment(of: [keysDeleted], timeout: 0)
    }
}
