//
//  Created on 2022-07-26.
//
//  Copyright (c) 2022 Proton AG
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

import Dependencies
import Foundation
@testable import ProtonVPN
import Testing
import VPNShared
import VPNSharedTesting

@Suite
struct SystemExtensionsClientTests {
    @Dependency(\.propertiesManager) private var propertiesManager

    @Test("shouldPerformInstallCheck uses protocol and profile dependencies")
    func shouldPerformInstallCheck() {
        propertiesManager.connectionProtocol = .smartProtocol

        let client = withDependencies {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $0.systemExtensionsProfilesClient = .init(hasCustomProfilesRequiringSystemExtension: { false })
        } operation: {
            SystemExtensionsClient.liveValue
        }

        #expect(client.shouldPerformInstallCheck())
    }

    @Test("installOrUpdateRaw forwards approval and completion")
    func installOrUpdateRawForwardsDriverEvents() async {
        let client = withDependencies {
            $0.systemExtensionsDriverClient = .init(
                installOrUpdateRaw: { _, includedTypes, _, userActionRequiredHandler, completion in
                    userActionRequiredHandler(includedTypes)
                    completion(
                        .init(
                            accumulated: .success(.installed),
                            individualResults: Dictionary(
                                uniqueKeysWithValues: includedTypes.map { ($0, .success(.installed)) }
                            ),
                            didRequireUserApproval: true
                        )
                    )
                },
                uninstallAll: { _, _, _ in .success }
            )
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $0.systemExtensionsProfilesClient = .init(hasCustomProfilesRequiringSystemExtension: { false })
        } operation: {
            SystemExtensionsClient.liveValue
        }

        let approvals = LockIsolated<[SystemExtensionType]>([])
        let raw = await client.installOrUpdateRaw(true, [.wireGuard]) { types in
            approvals.setValue(types)
        }

        #expect(approvals.value == [.wireGuard])
        #expect(raw.didRequireUserApproval)
        #expect(raw.individualResults[.wireGuard] != nil)
    }

    @Test("uninstallAll forwards to driver")
    func uninstallAllForwardsToDriver() async {
        let client = withDependencies {
            $0.systemExtensionsDriverClient = .init(
                installOrUpdateRaw: { _, _, _, _, _ in },
                uninstallAll: { _, _, _ in .timedOut }
            )
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $0.systemExtensionsProfilesClient = .init(hasCustomProfilesRequiringSystemExtension: { false })
        } operation: {
            SystemExtensionsClient.liveValue
        }

        #expect(await client.uninstallAll(true, nil) == .timedOut)
    }
}
