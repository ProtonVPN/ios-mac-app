//
//  Created on 02/07/2026 by Max Kupetskyi.
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

@testable import CommonNetworking
import Dependencies
import Domain
import Foundation
import Sharing
import Testing
import VPNAppCore

@Suite(.serialized)
struct LogoutCleanupTests {
    @Test("performLogoutCleanup resets user-scoped settings to their defaults")
    func resetsSettings() throws {
        let suiteName = "LogoutCleanupTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.hasConnected) var hasConnected
            @Shared(.discourageSecureCore) var discourageSecureCore
            @Shared(.reportBugEmail) var reportBugEmail
            @Shared(.secureCoreToggle) var secureCoreToggle
            @Shared(.alternativeRouting) var alternativeRouting
            @Shared(.smartProtocol) var smartProtocol
            @Shared(.killSwitch) var killSwitch

            // Seed non-default values.
            $hasConnected.withLock { $0 = true }
            $discourageSecureCore.withLock { $0 = false }
            $reportBugEmail.withLock { $0 = "x@y.com" }
            $secureCoreToggle.withLock { $0 = true }
            $alternativeRouting.withLock { $0 = false }
            $smartProtocol.withLock { $0 = !ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault }
            $killSwitch.withLock { $0 = true }

            performLogoutCleanup()

            #expect(hasConnected == false)
            #expect(discourageSecureCore == true)
            #expect(reportBugEmail == nil)
            #expect(secureCoreToggle == false)
            #expect(alternativeRouting == true)
            #expect(smartProtocol == ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault)
            #expect(killSwitch == false)
        }
    }
}
