//
//  Created on 14.03.2022.
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
import UIKit
@testable import Search

final class CountryViewModelMock: CountryViewModel {
    let description: String

    let isSmartAvailable: Bool = false

    let torAvailable: Bool = false

    let p2pAvailable: Bool = false

    let connectIcon: UIImage? = nil

    let textInPlaceOfConnectIcon: String? = nil

    var connectionChanged: (() -> Void)?

    let alphaOfMainElements: CGFloat = 1

    let flag: UIImage? = nil

    let connectButtonColor: UIColor = .darkGray

    let textColor: UIColor = .white

    let servers: [ServerTier: [ServerViewModel]]

    let isSecureCoreCountry: Bool

    func updateTier() {

    }

    func connectAction() {

    }

    let cities: [CityViewModel]

    init(country: String, servers: [ServerTier: [ServerViewModel]], isSecureCoreCountry: Bool = false) {
        description = country
        self.servers = servers
        self.isSecureCoreCountry = isSecureCoreCountry

        let servers = ServerTier.sorted(by: .plus).flatMap({ servers[$0] ?? [] })
        let groups = Dictionary.init(grouping: servers, by: { $0.city })
        self.cities = groups.map({
            CityViewModelMock(cityName: $0.key, countryName: country)
        }).sorted(by: { $0.cityName < $1.cityName })
    }

    func getServers() -> [ServerTier: [ServerViewModel]] {
        return servers
    }

    func getCities() -> [CityViewModel] {
        return cities
    }
}
