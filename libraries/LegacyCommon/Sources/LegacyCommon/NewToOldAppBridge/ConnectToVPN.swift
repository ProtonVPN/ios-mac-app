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

import Connection
import Domain
import Persistence
import ProtonCoreFeatureFlags
import VPNAppCore

import protocol Foundation.LocalizedError

import ComposableArchitecture

extension ConnectToVPNKey: @retroactive DependencyKey {
    enum ConnectionError: LocalizedError {
        case cancelled

        var errorDescription: String? {
            switch self {
            case .cancelled:
                "Connection attempt cancelled"
            }
        }
    }

    private static var isEnabled: Bool {
        FeatureFlagsRepository.isConnectionFeatureEnabled
    }

    public static let liveValue = if Self.isEnabled {
        newConnect
    } else {
        legacyConnect
    }

    static let newConnect: @Sendable (
        ConnectionSpec,
        ConnectionProtocol?,
        UserInitiatedVPNChange.VPNTrigger?
    ) async throws -> Void = { spec, specifiedProtocol, trigger in
        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(trigger))

        // Let's grab protocol information from PropertiesManager until redesigned settings are in place
        @Dependency(\.propertiesManager) var propertiesManager
        let connectionProtocol = specifiedProtocol ?? propertiesManager.connectionProtocol
        let acceptableProtocols: ProtocolSupport = switch connectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            vpnProtocol.protocolSupport
        case .smartProtocol:
            propertiesManager.smartProtocolConfig.supportedProtocols
                .reduce(.zero) { $0.union($1.protocolSupport) }
        }

        @Dependency(\.connectionBridge) var bridge
        await bridge
            .push(
                intent:
                .connect(
                    ConnectionPreparationIntent(
                        spec: spec,
                        connectionProtocol: connectionProtocol,
                        acceptableProtocols: acceptableProtocols
                    )
                )
            )
    }
}
