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
import VPNShared
import VPNSharedTesting
import CoreConnection
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

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
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
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }
        await store.receive(\.loadingFinished.success)
    }

    @MainActor func testRefreshesMissingOrExpiredCertificate() async {
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let storageMock = MockVpnAuthenticationStorage()
        storageMock.keys = mockKeys
        storageMock.cert = nil

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.certificateRefreshClient = .init(
                refreshCertificate: {
                    storageMock.cert = mockCertificate
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
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }
        await store.receive(\.loadingFinished.success)
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
                refreshCertificate: { .ok }, // Extension responds with .ok but doesn't actually update the certificate
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
                refreshCertificate: { .requiresNewKeys }, // Extension responds with .ok but doesn't actually update the certificate
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
