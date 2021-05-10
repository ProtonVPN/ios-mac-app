//
//  CreateNewProfileViewModel+Descriptors.swift
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

extension CreateNewProfileViewModel {
    
    internal func countryDescriptor(for country: CountryModel) -> NSAttributedString {
        let imageAttributedString = embededImageIcon(named: country.countryCode.lowercased() + "-plain")
        let countryString = ("  " + country.country)
        let nameAttributedString: NSAttributedString
        if country.lowestTier <= userTier {
            nameAttributedString = countryString.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        } else {
            nameAttributedString = (countryString + " (\(LocalizedString.upgradeRequired))").attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .left)
        }
        return NSAttributedString.concatenate(imageAttributedString, nameAttributedString)
    }
    
    internal func serverDescriptor(for server: ServerModel) -> NSAttributedString {
        if server.isSecureCore {
            let via = "via  ".attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            let entryCountryFlag = embededImageIcon(named: server.entryCountryCode.lowercased() + "-plain")
            let entryCountry = ("  " + server.entryCountry).attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            return NSAttributedString.concatenate(via, entryCountryFlag, entryCountry)
        } else {
            let countryFlag = embededImageIcon(named: server.countryCode.lowercased() + "-plain")
            let serverString = "  " + server.name
            let serverDescriptor: NSAttributedString
            if server.tier <= userTier {
                serverDescriptor = serverString.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            } else {
                serverDescriptor = (serverString + " (\(LocalizedString.upgradeRequired))").attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .left)
            }
            return NSAttributedString.concatenate(countryFlag, serverDescriptor)
        }
    }
    
    internal func defaultServerDescriptor(forIndex index: Int) -> NSAttributedString {
        let imageName: String
        let name: String
        
        switch index {
        case DefaultServerOffering.fastest.index:
            imageName = DefaultServerOffering.fastest.name
            name = LocalizedString.fastest
        default:
            imageName = DefaultServerOffering.random.name
            name = LocalizedString.random
        }
        
        let imageAttributedString = embededImageIcon(named: imageName)
        let nameAttributedString = ("  " + name).attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        return NSAttributedString.concatenate(imageAttributedString, nameAttributedString)
    }
    
    private func embededImageIcon(named name: String) -> NSAttributedString {
        if let imageAttributedString = NSAttributedString.imageAttachment(named: name, width: 18, height: 12) {
            return imageAttributedString
        }
        return NSAttributedString(string: "")
    }
}
