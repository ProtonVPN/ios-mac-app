//
//  Created on 2023-06-16.
//
//  Copyright (c) 2023 Proton AG
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

import ComposableArchitecture
import Connection
import ProtonCoreFeatureFlags
import Domain
import VPNAppCore

extension DisconnectVPNKey: DependencyKey {
    public static let liveValue = {
        let isEnabled = FeatureFlagsRepository.shared.isConnectionFeatureEnabled
        if isEnabled, #available(iOS 16, *) {
            return newDisconnect
        } else {
            return legacyDisconnect
        }
    }()

    public static let newDisconnect: @Sendable () async throws -> Void = {
        Dependency(\.connectionBridge).wrappedValue.push(intent: .disconnect(.userIntent))
    }

    /// Bridges new disconnection dependency with the legacy connection layer
    public static let legacyDisconnect: @Sendable () async throws -> Void = {
        @Dependency(\.siriHelper) var siriHelper
        siriHelper().donateDisconnect()

        let gateway = Container.sharedContainer.makeVpnGateway2()
        try await gateway.disconnect()

        // todo: old VpnGateway was reloading server info after disconnect. New one does not.
        // Decide where to put this functionality and implement it!
    }
}
