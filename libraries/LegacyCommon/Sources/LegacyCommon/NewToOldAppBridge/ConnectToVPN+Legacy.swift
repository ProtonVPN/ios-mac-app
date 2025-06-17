//
//  Created on 08/01/2025.
//
//  Copyright (c) 2025 Proton AG
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
import Domain
import VPNAppCore

import Foundation

extension ConnectToVPNKey {
    /// Bridges new connection dependency with the legacy connection layer
    /// Note: protocol parameter is ignored, since connections with this method originate from the home screen only, where
    /// it's not possible to specify the connection protocol
    static let legacyConnect: @Sendable (
        ConnectionSpec,
        ConnectionProtocol?,
        UserInitiatedVPNChange.VPNTrigger?
    ) async throws -> Void = { intent, _, _ in
        @Dependency(\.siriHelper) var siriHelper
        siriHelper().donateQuickConnect() // Change to more concrete donation when refactoring Siri stuff

        do {
            let gateway = Container.sharedContainer.makeVpnGateway2()
            try await gateway.connect(withIntent: intent)

            let propertyManager = Container.sharedContainer.makePropertiesManager()
            propertyManager.lastConnectionIntent = intent

        } catch VpnGateway2.GatewayError.noServerFound {
            log.error("No server found", metadata: ["intent": "\(intent)"])
            throw VpnGateway2.GatewayError.noServerFound // Not sure

        } catch let VpnGateway2.GatewayError.resolutionUnavailable(forSpecificCountry, type, reason) {
            log.warning("Server resolution unavailable", category: .connectionConnect, metadata: ["forSpecificCountry": "\(forSpecificCountry)", "type": "\(type)", "reason": "\(reason)", "intent": "\(intent)"])

//            Code from serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
            @Dependency(\.pushAlert) var alert

            switch reason {
            case .upgrade:
                alert(AllCountriesUpsellAlert())
            case .maintenance:
                alert(MaintenanceAlert(forSpecificCountry: forSpecificCountry))
            case .protocolNotSupported:
                alert(ProtocolNotAvailableForServerAlert())
            case let .locationNotFound(profileName):
                alert(LocationNotAvailableAlert(profileName: profileName))
            }
        } catch {
            throw error
        }
    }
}
