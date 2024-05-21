//
//  StreamingServicesOverlayViewModel.swift
//  ProtonVPN - Created on 22.04.21.
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

protocol StreamingServicesOverlayViewModelProtocol {
    var countryName: String { get }
    var columnsAmount: Int { get }
    var totalRows: Int { get }
    var totalItems: Int { get }
    func streamOptionViewModelFor(index: Int) -> StreamOptionCVItemViewModelProtocol
}

final class StreamingServicesOverlayViewModel: StreamingServicesOverlayViewModelProtocol {

    private let streamingServices: [VpnStreamingOption]
    
    let propertiesManager: PropertiesManagerProtocol
    
    init(country: String, streamServices: [VpnStreamingOption], propertiesManager: PropertiesManagerProtocol) {
        self.countryName = country
        self.streamingServices = streamServices
        self.propertiesManager = propertiesManager
    }
    
    // MARK: - ServersStreamingFeaturesViewModel
    
    let columnsAmount: Int = 3
    
    var totalRows: Int {
        return Int((Float(streamingServices.count) / Float(columnsAmount)).rounded(.up))
    }
    
    var totalItems: Int {
        return streamingServices.count
    }
    
    func streamOptionViewModelFor(index: Int) -> StreamOptionCVItemViewModelProtocol {
        return StreamOptionCVItemViewModel(streamingServices[index], propertiesManager: propertiesManager)
    }
    
    let countryName: String
}
