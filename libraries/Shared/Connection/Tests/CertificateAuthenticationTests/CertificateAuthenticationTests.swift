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
import ConnectionFoundations
import ConnectionFoundationsTestSupport
@testable import CertificateAuthentication

final class CertificateAuthenticationTests: XCTestCase {

    /// Tests authentication with no existing keys or certificates present.
    /// This mimics a 'fresh installation' scenario
    @MainActor func testEndToEndCertificateGeneration() async {
        let storageMock = MockVpnAuthenticationStorage() // Empty storage at the start of the test

        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))

        // Keys and certificate that we will place in the keychain during the test
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        var hasSelector: Bool = false

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.vpnKeysGenerator = .init(generateKeys: { mockKeys })
            $0.certificateRefreshClient = .init(
                refreshCertificate: {
                    guard hasSelector else { return .sessionMissingOrExpired }
                    storageMock.cert = mockCertificate
                    return .ok
                },
                pushSelector: { hasSelector = true}
            )
        }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }

        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.keysMissing)

        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success.sessionMissingOrExpired)
        await store.receive(\.selectorPushingFinished.success)
        await store.receive(\.refreshCertificate)
        await store.receive(\.refreshFinished.success) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }

        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }

        await store.receive(\.loadingFinished.success)
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
}
