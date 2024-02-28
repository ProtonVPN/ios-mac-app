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
import LegacyCommon
import Localization
import Theme
import Strings

extension OverviewItemViewModel {
    
    internal func attributedName(forProfile profile: Profile) -> NSAttributedString {
        return profile.name.styled(font: .themeFont(.heading4), alignment: .left, lineBreakMode: .byTruncatingTail)
    }
    
    internal func attributedDescription(forProfile profile: Profile) -> NSAttributedString {
        switch profile.profileType {
        case .system:
            return systemProfileDescriptor(forProfile: profile)
        case .user:
            return userProfileDescriptor(forProfile: profile)
        }
    }
    
    private func systemProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .system else {
            return Localizable.unavailable.styled(font: .themeFont(.heading4), alignment: .left)
        }
        
        let description: NSAttributedString
        switch profile.serverOffering {
        case .fastest:
            description = Localizable.fastestAvailableServer.styled(font: .themeFont(.heading4), alignment: .left)
        case .random:
            description = Localizable.differentServerEachTime.styled(font: .themeFont(.heading4), alignment: .left)
        case .custom:
            description = Localizable.unavailable.styled(font: .themeFont(.heading4), alignment: .left)
        }
        return description
    }
    
    private func userProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .user else {
            return Localizable.unavailable.styled(font: .themeFont(.heading4), alignment: .left)
        }
        
        let description: NSAttributedString
        switch profile.serverOffering {
        case .fastest(let cCode):
            description = defaultServerDescriptor(profile.serverType, forCountry: cCode, description: Localizable.fastest)
        case .random(let cCode):
            description = defaultServerDescriptor(profile.serverType, forCountry: cCode, description: Localizable.random)
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
        let doubleArrow = AppTheme.Icon.chevronRight.asAttachment(style: .normal, size: .square(10))

        let result: NSAttributedString
        let buffer = "  ".styled(font: .themeFont(.heading4), alignment: .left)
        switch serverType {
        case .standard:
            result = NSAttributedString.concatenate(attributedCountryName, doubleArrow, profileDescription)
        case .secureCore:
            let icon = AppTheme.Icon.locks.asAttachment(style: .normal, size: .square(15))
            result = NSAttributedString.concatenate(icon, profileDescription, buffer, doubleArrow, buffer, attributedCountryName)
        case .p2p:
            let icon = AppTheme.Icon.arrowsSwitch.asAttachment(style: .normal, size: .square(15))
            result = NSAttributedString.concatenate(icon, buffer, attributedCountryName, doubleArrow, profileDescription)
        default: // case .tor:
            let icon = AppTheme.Icon.brandTor.asAttachment(style: .normal, size: .square(15))
            result = NSAttributedString.concatenate(icon, buffer, attributedCountryName, doubleArrow, profileDescription)
        }
        
        return result
    }
    
    private func customServerDescriptor(forModel serverModel: ServerModel) -> NSAttributedString {
        let doubleArrow = AppTheme.Icon.chevronRight.asAttachment(style: .normal, size: .square(10))

        let prefixIcon: NSImage?
        if serverModel.isSecureCore {
            prefixIcon = AppTheme.Icon.locks
        } else if serverModel.supportsTor {
            prefixIcon = AppTheme.Icon.brandTor
        } else if serverModel.supportsP2P {
            prefixIcon = AppTheme.Icon.arrowsSwitch
        } else {
            prefixIcon = nil
        }
        let buffer = prefixIcon == nil ? "" : "  "

        let prefixString = prefixIcon?.colored(.hint).asAttachment(style: .normal, size: .square(15)) ?? NSAttributedString()
        if serverModel.isSecureCore {
            let entryCountry = (buffer + serverModel.entryCountry + "  ").styled(font: .themeFont(.heading4), alignment: .left)
            let exitCountry = ("  " + serverModel.exitCountry + "  ").styled(font: .themeFont(.heading4), alignment: .left)
            return NSAttributedString.concatenate(prefixString, entryCountry, doubleArrow, exitCountry)
        } else {
            let countryName = (buffer + serverModel.country + "  ").styled(font: .themeFont(.heading4), alignment: .left)
            let serverName = ("  " + serverModel.name).styled(font: .themeFont(.heading4), alignment: .left)
            return NSAttributedString.concatenate(prefixString, countryName, doubleArrow, serverName)
        }
    }
}
