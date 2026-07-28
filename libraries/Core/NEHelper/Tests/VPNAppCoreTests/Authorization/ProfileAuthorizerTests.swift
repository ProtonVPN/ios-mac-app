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
import Testing
@testable import VPNAppCore
@testable import VPNShared

struct ProfileAuthorizerTests {
    struct TestCase: Sendable {
        let userTier: Int?
        let requiredTier: Int
        let canUseProfiles: Bool
        let canUseProfile: Bool
    }

    @Test(arguments: [
        TestCase(userTier: nil, requiredTier: .paidTier, canUseProfiles: false, canUseProfile: false),
        TestCase(userTier: .freeTier, requiredTier: .freeTier, canUseProfiles: false, canUseProfile: false),
        TestCase(userTier: .paidTier, requiredTier: .freeTier, canUseProfiles: true, canUseProfile: true),
        TestCase(userTier: .paidTier, requiredTier: .paidTier, canUseProfiles: true, canUseProfile: true),
        TestCase(userTier: .paidTier, requiredTier: .internalTier, canUseProfiles: true, canUseProfile: false),
        TestCase(userTier: .internalTier, requiredTier: .paidTier, canUseProfiles: true, canUseProfile: true),
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
