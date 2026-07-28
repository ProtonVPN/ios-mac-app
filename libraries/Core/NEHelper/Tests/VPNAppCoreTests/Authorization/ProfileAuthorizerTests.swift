//
//  Created on 10/07/2026 by Max Kupetskyi.
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
import Domain
import Testing
@testable import VPNAppCore
@testable import VPNShared

struct ProfileAuthorizerTests {
    struct TestCase: Sendable {
        let userTier: VpnTier?
        let requiredTier: VpnTier
        let canUseProfiles: Bool
        let canUseProfile: Bool
    }

    @Test(arguments: [
        TestCase(userTier: nil, requiredTier: .paid, canUseProfiles: false, canUseProfile: false),
        TestCase(userTier: .free, requiredTier: .free, canUseProfiles: false, canUseProfile: false),
        TestCase(userTier: .paid, requiredTier: .free, canUseProfiles: true, canUseProfile: true),
        TestCase(userTier: .paid, requiredTier: .paid, canUseProfiles: true, canUseProfile: true),
        TestCase(userTier: .paid, requiredTier: .internal, canUseProfiles: true, canUseProfile: false),
        TestCase(userTier: .internal, requiredTier: .paid, canUseProfiles: true, canUseProfile: true),
    ])
    func authorizesProfiles(testCase: TestCase) {
        let result = withDependencies {
            $0.credentialsProvider = .constant(
                credentials: testCase.userTier.map { .tier($0) }
            )
        } operation: {
            let authorizer = ProfileAuthorizer.liveValue
            return (
                canUseProfiles: authorizer.canUseProfiles,
                canUseProfile: authorizer.canUseProfile(ofTier: testCase.requiredTier)
            )
        }

        #expect(result.canUseProfiles == testCase.canUseProfiles)
        #expect(result.canUseProfile == testCase.canUseProfile)
    }
}
