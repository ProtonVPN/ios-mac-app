//
//  Created on 24/11/2022.
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

import Foundation

open class ServerItemViewModelCore {
    public let serverModel: ServerModel
    public var vpnGateway: VpnGatewayProtocol
    public let appStateManager: AppStateManager
    public let propertiesManager: PropertiesManagerProtocol

    public var isSmartAvailable: Bool { serverModel.isVirtual }
    public var isTorAvailable: Bool { serverModel.feature.contains(.tor) }
    public var isP2PAvailable: Bool { serverModel.feature.contains(.p2p) }
    public var isPartnerServer: Bool { serverModel.feature.contains(.partner) }

    public var isSecureCoreEnabled: Bool {
        return serverModel.isSecureCore
    }

    public var load: Int {
        return serverModel.load
    }

    public var underMaintenance: Bool {
        return serverModel.underMaintenance
    }

    public var isUsersTierTooLow: Bool {
        return userTier < serverModel.tier
    }

    public var isStreamingAvailable: Bool {
        guard !isSecureCoreEnabled,
              serverModel.feature.contains(.streaming) else { return false }
        let tier = String(serverModel.tier)
        let countryCode = serverModel.countryCode
        return propertiesManager.streamingServices[countryCode]?[tier] != nil
    }

    public var isCurrentProtocolSupported: Bool {
        return serverModel.supports(connectionProtocol: propertiesManager.connectionProtocol,
                                    smartProtocolConfig: propertiesManager.smartProtocolConfig)
    }

    public var alphaOfMainElements: CGFloat {
        if underMaintenance {
            return 0.25
        }

        if isUsersTierTooLow {
            return 0.5
        }

        return 1.0
    }

    public init(serverModel: ServerModel,
                vpnGateway: VpnGatewayProtocol,
                appStateManager: AppStateManager,
                propertiesManager: PropertiesManagerProtocol) {
        self.serverModel = serverModel
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.propertiesManager = propertiesManager
    }

    public var partners: [Partner] {
        guard isPartnerServer else {
            return []
        }
        return propertiesManager.partnerTypes
            .flatMap {
                $0.partners
            }
            .filter {
                $0.logicalIDs.contains(serverModel.id)
            }
    }

    var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return .freeTier
        }
    }
}
