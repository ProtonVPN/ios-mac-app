//
//  StreamOptionCVItemViewModel.swift
//  ProtonVPN - Created on 10.05.21.
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
import vpncore

protocol StreamOptionCVItemViewModelProtocol {
    var serviceName: String { get }
    var url: URL? { get }
}

class StreamOptionCVItemViewModel: StreamOptionCVItemViewModelProtocol {
    
    var serviceName: String { option.name }
    
    var url: URL? {
        guard propertiesManager.featureFlags.streamingServicesLogos,
              let baseUrl = propertiesManager.streamingResourcesUrl else { return nil }
        let icon = option.icon
        return URL(string: baseUrl + icon )
    }
    
    private let option: VpnStreamingOption
    private let propertiesManager: PropertiesManagerProtocol
    
    init(_ option: VpnStreamingOption, propertiesManager: PropertiesManagerProtocol) {
        self.option = option
        self.propertiesManager = propertiesManager
    }    
}
