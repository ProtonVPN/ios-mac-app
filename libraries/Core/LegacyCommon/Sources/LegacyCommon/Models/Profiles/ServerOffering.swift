//
//  ServerOffering.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import CommonNetworking
import Dependencies
import Domain
import Foundation
import Persistence
import VPNAppCore

public extension ServerOffering {
    var description: String {
        switch self {
        case let .fastest(cCode):
            "Fastest server - \(String(describing: cCode))"
        case let .random(cCode):
            "Random server - \(String(describing: cCode))"
        case let .custom(sModel):
            "Custom server - \(String(describing: sModel))"
        }
    }

    var countryCode: String? {
        switch self {
        case let .fastest(cCode):
            cCode
        case let .random(cCode):
            cCode
        case let .custom(sModel):
            sModel.server.countryCode
        }
    }

    /// Check if offering can find any actually available server/protocol
    func supports(
        connectionProtocol: ConnectionProtocol,
        withCountryGroup grouping: ServerGroupInfo?,
        smartProtocolConfig: SmartProtocolConfig
    ) -> Bool {
        switch self {
        case let .fastest(countryCode), let .random(countryCode):
            guard let grouping else {
                return true
            }
            assert(grouping.serverOfferingID == countryCode, "Mismatched grouping while checking server protocol support (\(grouping.kind))")

            let supportedProtocols = connectionProtocol.vpnProtocol != nil
                ? [connectionProtocol.vpnProtocol!]
                : smartProtocolConfig.supportedProtocols

            return !grouping.protocolSupport.isDisjoint(with: ProtocolSupport(vpnProtocols: supportedProtocols))

        case let .custom(wrapper):
            return wrapper.server.supports(
                connectionProtocol: connectionProtocol,
                smartProtocolConfig: smartProtocolConfig
            )
        }
    }
}

public extension ServerGroupInfo {
    var serverOfferingID: String {
        kind.cacheID
    }
}

public extension ServerGroupInfo.Kind {
    var cacheID: String {
        switch self {
        case let .country(countryCode):
            countryCode
        case let .gateway(name):
            "gateway-\(name)"
        case let .city(name, _):
            "city-\(name)"
        case let .state(name, _):
            "state-\(name)"
        }
    }
}
