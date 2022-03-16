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
        return profile.name.styled(font: .themeFont(.heading4), alignment: .left, lineBreakMode: .byTruncatingTail)
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
            return LocalizedString.unavailable.styled(font: .themeFont(.heading4), alignment: .left)
        }
        
        let description: NSAttributedString
        switch profile.serverOffering {
        case .fastest:
            description = LocalizedString.fastestAvailableServer.styled(font: .themeFont(.heading4), alignment: .left)
        case .random:
            description = LocalizedString.differentServerEachTime.styled(font: .themeFont(.heading4), alignment: .left)
        case .custom:
            description = LocalizedString.unavailable.styled(font: .themeFont(.heading4), alignment: .left)
        }
        return description
    }
    
    private func userProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .user else {
            return LocalizedString.unavailable.styled(font: .themeFont(.heading4), alignment: .left)
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
            return description.styled(font: .themeFont(.heading4), alignment: .left)
        }
        
        let profileDescription = ("  " + description).styled(font: .themeFont(.heading4), alignment: .left)
        let countryName = LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
        let attributedCountryName = (countryName + "  ").styled(font: .themeFont(.heading4), alignment: .left)
        let doubleArrow = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(10))

        let description: NSAttributedString
        let buffer = "  ".styled(font: .themeFont(.heading4), alignment: .left)
        switch serverType {
        case .standard:
            description = NSAttributedString.concatenate(attributedCountryName, doubleArrow, profileDescription)
        case .secureCore:
            let icon = AppTheme.Icon.shield.asAttachment(style: .interactive, size: .square(15))
            description = NSAttributedString.concatenate(icon, profileDescription, buffer, doubleArrow, buffer, attributedCountryName)
        case .p2p:
            let icon = AppTheme.Icon.arrowsSwitch.asAttachment(style: .interactive, size: .square(15))
            description = NSAttributedString.concatenate(icon, buffer, attributedCountryName, doubleArrow, profileDescription)
        default: // case .tor:
            let icon = AppTheme.Icon.brandTor.asAttachment(style: .interactive, size: .square(15))
            description = NSAttributedString.concatenate(icon, buffer, attributedCountryName, doubleArrow, profileDescription)
        }
        
        return description
    }
    
    private func customServerDescriptor(forModel serverModel: ServerModel) -> NSAttributedString {
        let doubleArrow = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(10))

        if serverModel.isSecureCore {
            let secureCoreIcon = AppTheme.Icon.shield.asAttachment(style: .interactive, size: .square(14))
            let entryCountry = ("  " + serverModel.entryCountry + "  ").styled(font: .themeFont(.heading4), alignment: .left)
            let exitCountry = ("  " + serverModel.exitCountry + "  ").styled(font: .themeFont(.heading4), alignment: .left)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrow, exitCountry)
        } else {
            let countryName = (serverModel.country + "  ").styled(font: .themeFont(.heading4), alignment: .left)
            let serverName = ("  " + serverModel.name).styled(font: .themeFont(.heading4), alignment: .left)
            return NSAttributedString.concatenate(countryName, doubleArrow, serverName)
        }
    }
}
