//
//  Created on 07/01/2026 by Max Kupetskyi.
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
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Domain
@testable import ios_app
import LegacyCommon
import VPNShared

class FactoryMock: CountryItemViewModel.Factory, ConnectionStatusServiceFactory {
    let userTier: Int

    init(userTier: Int = 0) {
        self.userTier = userTier
    }

    func makeCoreAlertService() -> CoreAlertService {
        CoreAlertServiceDummy()
    }

    func makeVpnGateway() -> VpnGatewayProtocol {
        VpnGatewayMock(userTier: userTier)
    }

    func makeConnectionStatusService() -> ConnectionStatusService {
        ConnectionStatusServiceMock()
    }
}

extension CountryItemViewModel {
    static func mock(
        countryCode: String = "US",
        countryName _: String = "United States",
        features: ServerFeature = [],
        minTier: Int = 0,
        maxTier: Int = 2,
        serverCount: Int = 10,
        showCountryConnectButton: Bool = true,
        showFeatureIcons: Bool = true,
        userTier: Int = 0
    ) -> CountryItemViewModel {
        let serversGroup = ServerGroupInfo(
            kind: .country(code: countryCode),
            featureIntersection: features,
            featureUnion: features,
            minTier: minTier,
            maxTier: maxTier,
            serverCount: serverCount,
            cityCount: 0,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: ProtocolSupport.all
        )

        return CountryItemViewModel(
            factory: FactoryMock(userTier: userTier),
            serversGroup: serversGroup,
            serverType: .standard,
            connectionStatusService: ConnectionStatusServiceMock(),
            serversFilter: nil,
            showCountryConnectButton: showCountryConnectButton,
            showFeatureIcons: showFeatureIcons
        )
    }

    static let normalCountry = mock(
        countryCode: "US",
        countryName: "United States",
        features: [.secureCore, .p2p],
        serverCount: 150
    )

    static let plusCountry = mock(
        countryCode: "GB",
        countryName: "United Kingdom",
        features: [.ipv6, .p2p, .streaming],
        minTier: 2,
        maxTier: 2,
        serverCount: 80,
        userTier: 2
    )

    static let secureCoreCountry = mock(
        countryCode: "CH",
        countryName: "Switzerland",
        features: [.secureCore],
        minTier: 2,
        maxTier: 2,
        serverCount: 20,
        userTier: 2
    )

    static let freeCountry = mock(
        countryCode: "NL",
        countryName: "Netherlands",
        features: [],
        minTier: 0,
        maxTier: 0,
        serverCount: 5
    )

    static let torCountry = mock(
        countryCode: "SE",
        countryName: "Sweden",
        features: [.tor, .p2p],
        minTier: 2,
        maxTier: 2,
        serverCount: 30,
        userTier: 2
    )
}
