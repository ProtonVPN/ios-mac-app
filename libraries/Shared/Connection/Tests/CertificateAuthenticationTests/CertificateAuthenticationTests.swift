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

    @MainActor func testChecksForExistingCertificateBeforeRequestingRefresh() async {
        // let server = ServerEndpoint(id: "serverID", entryIp: "", exitIp: "", domain: "", status: 1, label: "1", x25519PublicKey: nil, protocolEntries: nil)
        let now = Date()
        let tomorrow = now.addingTimeInterval(.days(1))
        let storageMock = MockVpnAuthenticationStorage()
        let mockKeys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let mockCertificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let store = TestStore(initialState: .idle) {
            CertificateAuthenticationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.vpnAuthenticationStorage = storageMock
            $0.vpnKeysGenerator = .init(generateKeys: { mockKeys })
            $0.certificateRefreshClient = .init(
                refreshCertificate: {
                    storageMock.cert = mockCertificate
                    return .ok
                },
                pushSelector: { }
            )
        }

        let keysStored = XCTestExpectation(description: "Expected feature to generate new keys")
        storageMock.keysStored = { _ in keysStored.fulfill() }

        await store.send(.loadAuthenticationData) {
            $0 = .loading(shouldRefreshIfNecessary: true)
        }
        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.keysMissing)

        await fulfillment(of: [keysStored], timeout: 1)

        await store.receive(\.refreshCertificate) {
            $0 = .loading(shouldRefreshIfNecessary: false)
        }
        await store.receive(\.refreshFinished.success)

        await store.receive(\.loadFromStorage)
        await store.receive(\.loadingFromStorageFinished.loaded) {
            $0 = .loaded(.init(keys: .init(fromLegacyKeys: mockKeys), certificate: mockCertificate))
        }
        await store.receive(\.loadingFinished.success)
    }

    func testPromptsForCertificateRefreshIfCertificateExpired() {

    }
}
