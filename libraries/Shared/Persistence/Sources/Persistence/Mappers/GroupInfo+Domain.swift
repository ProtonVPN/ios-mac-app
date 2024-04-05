//
//  Created on 18/12/2023.
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

import Domain

extension GroupInfoResult {
    var domainModel: ServerGroupInfo {
        return .init(
            kind: kind,
            featureIntersection: featureIntersection,
            featureUnion: featureUnion,
            minTier: minTier,
            maxTier: maxTier,
            serverCount: serverCount,
            cityCount: cityCount,
            latitude: latitude,
            longitude: longitude,
            supportsSmartRouting: isVirtual == 1,
            isUnderMaintenance: statusUnion == 0,
            protocolSupport: protocolSupport
        )
    }

    private var kind: ServerGroupInfo.Kind {
        if let gatewayName {
            return .gateway(name: gatewayName)
        } else {
            return .country(code: exitCountryCode)
        }
    }
}
