//
//  Created on 28/04/2026 by Max Kupetskyi.
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
import DependenciesMacros
import Foundation
import LegacyCommon

@DependencyClient
struct SystemExtensionsClient {
    var installOrUpdateRaw: @Sendable (
        _ userInitiated: Bool,
        _ includedTypes: [SystemExtensionType],
        _ onApprovalRequired: @escaping ([SystemExtensionType]) -> Void
    ) async -> SystemExtensionRawInstallationResult = { _, includedTypes, _ in
        .init(
            accumulated: .success(.alreadyThere),
            individualResults: Dictionary(uniqueKeysWithValues: includedTypes.map { ($0, .success(.alreadyThere)) }),
            didRequireUserApproval: false
        )
    }

    var shouldPerformInstallCheck: @Sendable () -> Bool = { false }
    var uninstallAll: @Sendable (_ userInitiated: Bool, _ timeout: DispatchTime?) async -> DispatchTimeoutResult = { _, _ in .success }
}

extension SystemExtensionsClient: DependencyKey {
    static var liveValue: SystemExtensionsClient {
        @Dependency(\.systemExtensionsDriverClient) var driver
        @Dependency(\.propertiesManager) var propertiesManager
        @Dependency(\.systemExtensionsProfilesClient) var profilesClient
        @Dependency(\.vpnKeychain) var vpnKeychain

        return .init(
            installOrUpdateRaw: { userInitiated, includedTypes, onApprovalRequired in
                await withCheckedContinuation { continuation in
                    driver.installOrUpdateRaw(
                        userInitiated: userInitiated,
                        includedTypes: includedTypes,
                        replacementPolicy: { existing, newExtension in
                            existing < newExtension || propertiesManager.forceExtensionUpgrade
                        },
                        userActionRequiredHandler: { requiringApprovalTypes in
                            onApprovalRequired(requiringApprovalTypes)
                        },
                        completion: { rawResult in
                            continuation.resume(returning: rawResult)
                        }
                    )
                }
            },
            shouldPerformInstallCheck: {
                vpnKeychain.userIsLoggedIn &&
                    (
                        propertiesManager.connectionProtocol.requiresSystemExtension ||
                            profilesClient.hasCustomProfilesRequiringSystemExtension()
                    )
            },
            uninstallAll: { userInitiated, timeout in
                driver.uninstallAll(
                    userInitiated: userInitiated,
                    timeout: timeout,
                    replacementPolicy: { existing, newExtension in
                        existing < newExtension || propertiesManager.forceExtensionUpgrade
                    }
                )
            }
        )
    }

    #if DEBUG
        static var testValue: SystemExtensionsClient {
            .init(
                installOrUpdateRaw: { _, includedTypes, _ in
                    .init(
                        accumulated: .success(.installed),
                        individualResults: Dictionary(
                            uniqueKeysWithValues: includedTypes.map { ($0, .success(.installed)) }
                        ),
                        didRequireUserApproval: false
                    )
                },
                shouldPerformInstallCheck: { true },
                uninstallAll: { _, _ in .success }
            )
        }
    #endif
}

extension DependencyValues {
    var systemExtensionsClient: SystemExtensionsClient {
        get { self[SystemExtensionsClient.self] }
        set { self[SystemExtensionsClient.self] = newValue }
    }
}
