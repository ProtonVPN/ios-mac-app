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

import Announcement
import CommonNetworking
import Dependencies
import Domain
import Modals
@testable import ios_app
import LegacyCommon
import Observation
import VPNShared

@Observable
class CountriesViewModelMock: CountriesViewModel {
    init(sections: [CountrySection]) {
        super.init(factory: FactoryMock())
        self.sections = sections
    }

    override func presentAllCountriesUpsell() {}
    override func presentUpsell(forCountryCode _: String) {}
    override func presentFreeConnectionsInfo() {}
}

extension CountriesViewModelMock {
    static var standardMode: CountriesViewModelMock {
        let countries: [Row] = [
            .serverGroup(CountryItemViewModel.normalCountry),
            .serverGroup(CountryItemViewModel.plusCountry),
            .serverGroup(CountryItemViewModel.freeCountry),
        ]

        let sections: [CountrySection] = [
            .countries(title: nil, rows: countries, serversFilter: nil, showFeatureIcons: true),
        ]

        return CountriesViewModelMock(sections: sections)
    }

    static var secureCoreMode: CountriesViewModelMock {
        let countries: [Row] = [
            .serverGroup(CountryItemViewModel.secureCoreCountry),
        ]

        let sections: [CountrySection] = [
            .countries(title: nil, rows: countries, serversFilter: nil, showFeatureIcons: true),
        ]

        let mock = CountriesViewModelMock(sections: sections)
        mock.setStateOf(type: .secureCore)
        return mock
    }

    static var withBanners: CountriesViewModelMock {
        let rows: [Row] = [
            .banner(BannerViewModel.upsellBanner),
            .offerBanner(OfferBannerViewModel.withCountdown),
            .serverGroup(CountryItemViewModel.normalCountry),
            .serverGroup(CountryItemViewModel.plusCountry),
        ]

        let sections: [CountrySection] = [
            .countries(title: nil, rows: rows, serversFilter: nil, showFeatureIcons: true),
        ]

        return CountriesViewModelMock(sections: sections)
    }

    static var freeUser: CountriesViewModelMock {
        let countries: [Row] = [
            .serverGroup(CountryItemViewModel.freeCountry),
            .serverGroup(CountryItemViewModel.mock(
                countryCode: "JP",
                countryName: "Japan",
                features: [],
                minTier: 0,
                maxTier: 0,
                serverCount: 3,
                userTier: 0
            )),
        ]

        let sections: [CountrySection] = [
            .countries(title: "FREE SERVERS (2)", rows: countries, serversFilter: nil, showFeatureIcons: true),
        ]

        return CountriesViewModelMock(sections: sections)
    }
}
