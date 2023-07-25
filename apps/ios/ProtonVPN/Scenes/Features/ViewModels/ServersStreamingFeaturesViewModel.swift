//
//  ServersStreamingFeaturesViewModel.swift
//  ProtonVPN - Created on 20.04.21.
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

import Foundation
import LegacyCommon

protocol ServersStreamingFeaturesViewModel {
    var countryName: String { get }
    var columnsAmount: Int { get }
    var totalRows: Int { get }
    var totalItems: Int { get }
    
    func vpnOption( for index: Int ) -> VpnStreamingOption
    
    var propertiesManager: PropertiesManagerProtocol { get }
}

class ServersStreamingFeaturesViewModelImplementation: ServersStreamingFeaturesViewModel {

    private let streamingServices: [VpnStreamingOption]
    
    let propertiesManager: PropertiesManagerProtocol
    
    init( country: String, streamServices: [VpnStreamingOption], propertiesManager: PropertiesManagerProtocol) {
        self.countryName = country
        self.streamingServices = streamServices
        self.propertiesManager = propertiesManager
    }
        
    let columnsAmount: Int = 4
    
    var totalRows: Int {
        return Int( (Float(streamingServices.count) / Float(columnsAmount) ).rounded(.up) )
    }
    
    let countryName: String
    
    var totalItems: Int {
        return streamingServices.count
    }
    
    func vpnOption(for index: Int) -> VpnStreamingOption {
        return streamingServices[index]
    }
}
