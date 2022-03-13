//
//  CountriesServersHeaderViewModel.swift
//  ProtonVPN - Created on 28.04.21.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import vpncore

protocol CountriesServersHeaderViewModelProtocol {
    var title: String { get }
    var backgroundColor: CGColor { get }
    var didTapInfoBtn: ( () -> Void )? { get }
}

class CountryHeaderViewModel: CountriesServersHeaderViewModelProtocol {
    let title: String
    let backgroundColor: CGColor = .cgColor(.background)
    var didTapInfoBtn: (() -> Void)?
    
    init( _ sectionHeader: String, totalCountries: Int, isPremium: Bool, countriesViewModel: CountriesSectionViewModel ) {
        title = sectionHeader + " (\(totalCountries))"
        guard isPremium else { return }
        didTapInfoBtn = {
            countriesViewModel.displayPremiumServices?()
        }
    }
}

class ServerHeaderViewModel: CountriesServersHeaderViewModelProtocol {
    let title: String
    let backgroundColor: CGColor = .cgColor(.background, .weak)
    var didTapInfoBtn: (() -> Void)?
    
    init( _ sectionHeader: String, totalServers: Int, country: CountryModel, tier: Int, propertiesManager: PropertiesManagerProtocol, countriesViewModel: CountriesSectionViewModel) {
        title = sectionHeader + " (\(totalServers))"
        guard !propertiesManager.secureCoreToggle, tier > 1, let streamServicesDict = propertiesManager.streamingServices[country.countryCode],
              let key = streamServicesDict.keys.first, let streamServices = streamServicesDict[key] else {
            return
        }
        
        didTapInfoBtn = {
            countriesViewModel.displayStreamingServices?(country.country, streamServices, propertiesManager)
        }
    }
}
