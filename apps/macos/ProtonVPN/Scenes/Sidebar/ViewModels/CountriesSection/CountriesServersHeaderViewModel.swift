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

import Domain
import Strings

import LegacyCommon

protocol CountriesServersHeaderViewModelProtocol: AnyObject {
    var title: String { get }
    var didTapInfoBtn: ( () -> Void )? { get }
}

class CountryHeaderViewModel: CountriesServersHeaderViewModelProtocol {
    let title: String
    var didTapInfoBtn: (() -> Void)?
    
    init(
        _ sectionHeader: String,
        totalCountries: Int?,
        buttonType: InfoButtonType?,
        countriesViewModel: CountriesSectionViewModel
    ) {
        var title = sectionHeader
        if let totalCountries {
            title += " (\(totalCountries))"
        }
        self.title = title

        if let buttonType {
            didTapInfoBtn = { [weak countriesViewModel] in
                switch buttonType {
                case .premium:
                    countriesViewModel?.displayPremiumServices?()
                case .gateway:
                    countriesViewModel?.displayGatewaysServices?()
                case .freeConnections:
                    countriesViewModel?.displayFreeServices()
                }
            }
        }
    }

    enum InfoButtonType {
        case premium
        case gateway
        case freeConnections
    }
}

class ServerHeaderViewModel: CountriesServersHeaderViewModelProtocol {
    let title: String
    var didTapInfoBtn: (() -> Void)?
    
    init(
        _ sectionHeader: String,
        totalServers: Int,
        kind: ServerGroupInfo.Kind,
        tier: Int,
        propertiesManager: PropertiesManagerProtocol,
        countriesViewModel: CountriesSectionViewModel
    ) {
        title = sectionHeader + " (\(totalServers))"
        guard tier.isPaidTier else {
            didTapInfoBtn = { [weak countriesViewModel] in
                countriesViewModel?.displayFreeServices()
            }
            return
        }

        guard case .country(let code) = kind,
              !propertiesManager.secureCoreToggle,
              tier.isPaidTier,
              let streamServicesDict = propertiesManager.streamingServices[code],
              let key = streamServicesDict.keys.first,
              let streamServices = streamServicesDict[key] else {
            return
        }

        didTapInfoBtn = { [weak countriesViewModel] in
            let countryName = LocalizationUtility().countryName(forCode: code) ?? ""
            countriesViewModel?.displayStreamingServices?(countryName, streamServices, propertiesManager)
        }
    }
}
