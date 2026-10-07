//
//  Created on 07/10/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Foundation
import protun
@testable import ProTUNExtension
import Testing

@Suite("Persistent cache")
struct PersistentCacheTests {
    private static let invalidationDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func removesACertificateStoredBeforeTheInvalidation() {
        let removed = removedAccounts(certificateStoredAt: Self.invalidationDate.addingTimeInterval(-1))
        #expect(removed == [CacheKey.certificate.keychainAccount])
    }

    @Test
    func keepsACertificateStoredAfterTheInvalidation() {
        #expect(removedAccounts(certificateStoredAt: Self.invalidationDate.addingTimeInterval(1)).isEmpty)
    }

    @Test
    func keepsACertificateTheKeychainReportsNoDateFor() {
        #expect(removedAccounts(certificateStoredAt: nil).isEmpty)
    }

    /// The keychain accounts the cache removes when asked to drop a certificate stored before `invalidatedAt`, given
    /// the date the keychain reports for the certificate.
    private func removedAccounts(
        certificateStoredAt storedAt: Date?,
        invalidatedAt: Date = invalidationDate
    ) -> [String] {
        let removed = LockIsolated<[String]>([])
        var keychain = LightKeychain()
        keychain.modificationDate = { _, _ in (storedAt == nil ? errSecItemNotFound : errSecSuccess, storedAt) }
        keychain.removePassword = { _, account in
            removed.withValue { $0.append(account) }
            return errSecSuccess
        }

        withDependencies {
            $0.lightKeychain = keychain
        } operation: {
            SecurePersistentCache(userID: "user-id").removeCertificate(storedBefore: invalidatedAt)
        }

        return removed.value
    }
}
