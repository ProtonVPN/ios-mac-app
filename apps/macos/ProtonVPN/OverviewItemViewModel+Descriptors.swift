//
//  OverviewItemViewModel+Descriptors.swift
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

import Cocoa
import vpncore

extension OverviewItemViewModel {
    
    internal func attributedName(forProfile profile: Profile) -> NSAttributedString {
        return profile.name.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left, lineBreakMode: .byTruncatingTail)
    }
    
    internal func attributedDescription(forProfile profile: Profile) -> NSAttributedString {
        let description: NSAttributedString
        switch profile.profileType {
        case .system:
            description = systemProfileDescriptor(forProfile: profile)
        case .user:
            description = userProfileDescriptor(forProfile: profile)
        }
        return description
    }
    
    private func systemProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .system else {
            return LocalizedString.unavailable.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
        
        let description: NSAttributedString
        switch profile.serverOffering {
        case .fastest:
            description = LocalizedString.fastestAvailableServer.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        case .random:
            description = LocalizedString.differentServerEachTime.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        case .custom:
            description = LocalizedString.unavailable.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
        return description
    }
    
    private func userProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .user else {
            return LocalizedString.unavailable.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
        
        let description: NSAttributedString
        switch profile.serverOffering {
        case .fastest(let cCode):
            description = defaultServerDescriptor(profile.serverType, forCountry: cCode, description: LocalizedString.fastest)
        case .random(let cCode):
            description = defaultServerDescriptor(profile.serverType, forCountry: cCode, description: LocalizedString.random)
        case .custom(let sWrapper):
            description = customServerDescriptor(forModel: sWrapper.server)
        }
        return description
    }
    
    private func defaultServerDescriptor(_ serverType: ServerType, forCountry countryCode: String?, description: String) -> NSAttributedString {
        guard let countryCode = countryCode else {
            return description.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
        
        let profileDescription = ("  " + description).attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        let countryName = LocalizationUtility.countryName(forCode: countryCode) ?? ""
        let attributedCountryName = (countryName + "  ").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        let doubleArrow = NSAttributedString.imageAttachment(named: "double-arrow-right-white", width: 10, height: 10)!
        
        let description: NSAttributedString
        let buffer = "  ".attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        switch serverType {
        case .standard:
            description = NSAttributedString.concatenate(attributedCountryName, doubleArrow, profileDescription)
        case .secureCore:
            let icon = NSAttributedString.imageAttachment(named: "protonvpn-server-sc-available", width: 14, height: 15)!
            description = NSAttributedString.concatenate(icon, profileDescription, buffer, doubleArrow, buffer, attributedCountryName)
        case .p2p:
            let icon = NSAttributedString.imageAttachment(named: "protonvpn-server-p2p-available", width: 14, height: 12)!
            description = NSAttributedString.concatenate(icon, buffer, attributedCountryName, doubleArrow, profileDescription)
        default: // case .tor:
            let icon = NSAttributedString.imageAttachment(named: "protonvpn-server-tor-available", width: 14, height: 21)!
            description = NSAttributedString.concatenate(icon, buffer, attributedCountryName, doubleArrow, profileDescription)
        }
        
        return description
    }
    
    private func customServerDescriptor(forModel serverModel: ServerModel) -> NSAttributedString {
        let doubleArrow = NSAttributedString.imageAttachment(named: "double-arrow-right-white", width: 10, height: 10)!
        
        if serverModel.isSecureCore {
            let secureCoreIcon = NSAttributedString.imageAttachment(named: "protonvpn-server-sc-available", width: 14, height: 14)!
            let entryCountry = ("  " + serverModel.entryCountry + "  ").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            let exitCountry = ("  " + serverModel.exitCountry + "  ").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrow, exitCountry)
        } else {
            let countryName = (serverModel.country + "  ").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            let serverName = ("  " + serverModel.name).attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            return NSAttributedString.concatenate(countryName, doubleArrow, serverName)
        }
    }
}
