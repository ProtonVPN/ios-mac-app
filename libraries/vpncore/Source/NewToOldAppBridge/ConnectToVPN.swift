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

import Foundation
import ComposableArchitecture
import VPNAppCore

extension DependencyValues {

    /// ATM it's neither async nor throws, but the plan is to return only after connection is made and also to throw exceptions
    /// so user can be presented with an error from UI, and not from the depths of VPN connection related code.
    public var connectToVPN: @Sendable (ConnectionSpec) async throws -> Void {
        get { self[ConnectToVPNKey.self] }
        set { self[ConnectToVPNKey.self] = newValue }
    }
}

private enum ConnectToVPNKey: DependencyKey {
    static let liveValue: @Sendable (ConnectionSpec) async throws -> Void = { specs in
        @Dependency(\.siriHelper) var siriHelper
        siriHelper().donateQuickConnect() // Change to more concrete donation when refactoring Siri stuff

        do {
            let gateway = Container.sharedContainer.makeVpnGateway2()
            try await gateway.connect(withIntent: specs)

        } catch VpnGateway2.GatewayError.noServerFound {
            log.error("No server found")
            throw VpnGateway2.GatewayError.noServerFound // Not sure

        } catch VpnGateway2.GatewayError.resolutionUnavailable(let forSpecificCountry, let type, let reason) {
            log.warning("Server resolution unavailable", category: .connectionConnect, metadata: ["forSpecificCountry": "\(forSpecificCountry)", "type": "\(type)", "reason": "\(reason)"])

//            Code from serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
            @Dependency(\.pushAlert) var alert

            switch reason {
            case .upgrade:
                alert(AllCountriesUpsellAlert())
            case .maintenance:
                alert(MaintenanceAlert(forSpecificCountry: forSpecificCountry))
            case .protocolNotSupported:
                alert(ProtocolNotAvailableForServerAlert())
            }

        }
    }
}
