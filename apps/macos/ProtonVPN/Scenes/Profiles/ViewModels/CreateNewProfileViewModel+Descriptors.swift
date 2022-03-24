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
import AppKit

extension CreateNewProfileViewModel {
    private var fontSize: CGFloat {
        return 16
    }
    private var baselineOffset: CGFloat {
        return 4
    }

    internal func countryDescriptor(for country: CountryModel) -> NSAttributedString {
        let imageAttributedString = embededImageIcon(image: NSImage.flag(countryCode: country.countryCode))
        let countryString = "  " + country.country
        let nameAttributedString: NSAttributedString
        if country.lowestTier <= userTier {
            nameAttributedString = NSMutableAttributedString(
                string: countryString,
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: NSColor.dropDownWhiteColor()
                ]
            )
        } else {
            nameAttributedString = NSMutableAttributedString(
                string: countryString + " (\(LocalizedString.upgradeRequired))",
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: NSColor.protonGreyOutOfFocus()
                ]
            )
        }
        return NSAttributedString.concatenate(imageAttributedString, nameAttributedString)
    }
    
    internal func serverDescriptor(for server: ServerModel) -> NSAttributedString {
        if server.isSecureCore {
            let via = NSMutableAttributedString(
                string: "via  ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: NSColor.dropDownWhiteColor()
                ]
            )
            let entryCountryFlag = embededImageIcon(image: NSImage.flag(countryCode: server.entryCountryCode))
            let entryCountry = NSMutableAttributedString(
                string: "  " + server.entryCountry,
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: NSColor.dropDownWhiteColor()
                ]
            )
            return NSAttributedString.concatenate(via, entryCountryFlag, entryCountry)
        } else {
            let countryFlag = embededImageIcon(image: NSImage.flag(countryCode: server.countryCode))
            let serverString = "  " + server.name
            let serverDescriptor: NSAttributedString
            if server.tier <= userTier {
                serverDescriptor = NSMutableAttributedString(
                    string: serverString,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: fontSize),
                        .baselineOffset: baselineOffset,
                        .foregroundColor: NSColor.dropDownWhiteColor()
                    ]
                )
            } else {
                serverDescriptor = NSMutableAttributedString(
                    string: serverString + " (\(LocalizedString.upgradeRequired))",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: fontSize),
                        .baselineOffset: baselineOffset,
                        .foregroundColor: NSColor.dropDownWhiteColor()
                    ]
                )
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
        let nameAttributedString = NSMutableAttributedString(
            string: "  " + name,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize),
                .baselineOffset: baselineOffset,
                .foregroundColor: NSColor.dropDownWhiteColor()
            ]
        )
        return NSAttributedString.concatenate(imageAttributedString, nameAttributedString)
    }
    
    private func embededImageIcon(named name: String) -> NSAttributedString {
        if let imageAttributedString = NSAttributedString.imageAttachment(named: name, width: 18, height: 12) {
            return imageAttributedString
        }
        return NSAttributedString(string: "")
    }

    private func embededImageIcon(image: NSImage?) -> NSAttributedString {
        if let imageAttributedString = NSAttributedString.imageAttachment(image: image, width: 18, height: 18) {
            return imageAttributedString
        }
        return NSAttributedString(string: "")
    }
}
