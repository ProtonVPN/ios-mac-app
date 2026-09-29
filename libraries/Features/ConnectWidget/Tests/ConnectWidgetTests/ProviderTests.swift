//
//  Created on 29/09/2026 by Pawel Jurczyk.
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

@testable import ConnectWidget
import Dependencies
import Sharing
import Testing
import VPNShared

@Suite("Connect widget timeline provider")
struct ProviderTests {
    /// The widget process outlives a sign-out in the containing app, and `AuthKeychain` caches the
    /// username and user ID for the lifetime of its process. Only the process that signs out
    /// clears that cache, so the provider has to go back to the keychain on every request rather
    /// than trust the cached identity.
    @Test("Reports signed out once the keychain no longer holds credentials")
    func reportsSignedOutWhenKeychainClearedBehindAWarmCache() async {
        let authKeychain = MockAuthKeychain()
        authKeychain.setMockUsername("user")
        authKeychain.userId = "user-id"

        let entry = await withDependencies {
            $0.authKeychain = authKeychain
            $0.defaultAppStorage = .inMemory
            $0.calendar = .current
            $0.date = .constant(.now)
        } operation: {
            let provider = Provider()
            // Signing out in the app empties the keychain. The username and user ID cached by
            // *this* process survive it, which is what used to keep the widget looking signed in.
            authKeychain.clear(.logOutCleanup)
            return await provider.createTimelineEntry()
        }

        #expect(entry.protectionState == .signedOut)
        #expect(entry.recentServers.isEmpty)
    }
}
