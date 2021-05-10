//
//  ServerUtility.swift
//  ProtonVPN - Created on 27.06.19.
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

class ServerUtility {
    
    static func countryIndex(in grouping: [CountryGroup], countryCode: String) -> Int? {
        for (index, group) in grouping.enumerated() where group.0.countryCode == countryCode {
            return index
        }
        return nil
    }
    
    static func country(in grouping: [CountryGroup], index: Int) -> CountryModel? {
        if index >= 0 && index < grouping.count {
            return grouping[index].0
        }
        return nil
    }
    
    static func serverIndex(in grouping: [CountryGroup], model: ServerModel) -> Int? {
        guard let countryIndex = countryIndex(in: grouping, countryCode: model.countryCode) else {
            return nil
        }
        
        for (index, server) in grouping[countryIndex].1.enumerated() where server == model {
            return index
        }
        return nil
    }
    
    static func server(in grouping: [CountryGroup], countryIndex: Int, serverIndex: Int) -> ServerModel? {
        if countryIndex >= 0 && countryIndex < grouping.count,
            serverIndex >= 0 && serverIndex < grouping[countryIndex].1.count {
            return grouping[countryIndex].1[serverIndex]
        }
        return nil
    }
}
