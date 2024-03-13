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
import LegacyCommon
import AppKit
import Theme
import Strings
import ProtonCoreUIFoundations
import Domain

// FUTUREDO: This is very similar to what we have on iOS.
// We should work on merging code into one.
// I'm not doing it now, because there is a high chance
// that this code will be completely deleted during redesign.
extension CreateNewProfileViewModel {
    private var fontSize: AppTheme.FontSize {
        return .heading4
    }

    private var baselineOffset: CGFloat {
        return 4
    }

    private func flagString(_ countryCode: String) -> NSAttributedString {
        AppTheme.Icon.flag(countryCode: countryCode)?.asAttachment(size: .profileIconSize) ?? NSAttributedString(string: "")
    }

    // MARK: - Country / Gateway

    internal func countryDescriptor(for group: ServerGroupInfo) -> NSAttributedString {
        let imageAttributedString: NSAttributedString
        let countryString: String

        switch group.kind {
        case .country(let countryCode):
            imageAttributedString = AppTheme.Icon.flag(countryCode: countryCode)?.asAttachment(size: .profileIconSize) ?? NSAttributedString(string: "")
            countryString = "  " + (LocalizationUtility.default.countryName(forCode: countryCode) ?? "")
        case .gateway(let name):
            imageAttributedString = IconProvider.servers.asAttachment(style: .normal, size: .profileIconSize)
            countryString = "  " + name
        }

        let nameAttributedString: NSAttributedString
        if userTierSupports(group: group) {
            nameAttributedString = NSMutableAttributedString(
                string: countryString,
                attributes: [
                    .font: NSFont.themeFont(fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: self.color(.text)
                ]
            )
        } else {
            nameAttributedString = NSMutableAttributedString(
                string: countryString + " (\(Localizable.upgradeRequired))",
                attributes: [
                    .font: NSFont.themeFont(fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: NSColor.color(.text, .weak)
                ]
            )
        }
        return NSAttributedString.concatenate(imageAttributedString, nameAttributedString)
    }

    // MARK: - Server

    internal func serverDescriptor(for serverOffering: ServerOffering) -> NSAttributedString {
        switch serverOffering {
        case .custom(let serverWrapper):
            return serverDescriptor(for: serverWrapper.server)
        case .fastest:
            return defaultServerDescriptor(image: IconProvider.bolt, name: Localizable.fastest)
        case .random:
            return defaultServerDescriptor(image: IconProvider.arrowsSwapRight, name: Localizable.random)
        }
    }
    
    internal func serverDescriptor(for server: ServerModel) -> NSAttributedString {
        server.isSecureCore
            ? serverDescriptorForSecureCore(
                entryCountry: server.entryCountry,
                entryCountryCode: server.entryCountryCode
            )
            : serverDescriptorForStandard(
                serverName: server.name,
                countryCode: server.countryCode,
                serverTier: server.tier
            )
    }

    internal func serverDescriptor(for server: ServerInfo) -> NSAttributedString {
        return server.logical.feature.contains(.secureCore)
            ? serverDescriptorForSecureCore(
                entryCountry: server.logical.entryCountry,
                entryCountryCode: server.logical.entryCountryCode
            )
            : serverDescriptorForStandard(
                serverName: server.logical.name,
                countryCode: server.logical.exitCountryCode,
                serverTier: server.logical.tier
            )
    }

    private func serverDescriptorForSecureCore(entryCountry: String, entryCountryCode: String) -> NSAttributedString {
        let via = NSMutableAttributedString(
            string: "via  ",
            attributes: [
                .font: NSFont.themeFont(fontSize),
                .baselineOffset: baselineOffset,
                .foregroundColor: self.color(.text)
            ]
        )
        let entryCountryFlag = flagString(entryCountryCode)
        let entryCountry = NSMutableAttributedString(
            string: "  " + entryCountry,
            attributes: [
                .font: NSFont.themeFont(fontSize),
                .baselineOffset: baselineOffset,
                .foregroundColor: self.color(.text)
            ]
        )
        return NSAttributedString.concatenate(via, entryCountryFlag, entryCountry)
    }

    private func serverDescriptorForStandard(serverName: String, countryCode: String, serverTier: Int) -> NSAttributedString {
        let countryFlag = flagString(countryCode)
        let serverString = "  " + serverName
        let serverDescriptor: NSAttributedString
        if userTierSupports(serverWithTier: serverTier) {
            serverDescriptor = NSMutableAttributedString(
                string: serverString,
                attributes: [
                    .font: NSFont.themeFont(fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: self.color(.text)
                ]
            )
        } else {
            serverDescriptor = NSMutableAttributedString(
                string: serverString + " (\(Localizable.upgradeRequired))",
                attributes: [
                    .font: NSFont.themeFont(fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: self.color(.text)
                ]
            )
        }
        return NSAttributedString.concatenate(countryFlag, serverDescriptor)

    }

    internal func defaultServerDescriptor(image: NSImage, name: String) -> NSAttributedString {
        let imageAttributedString = self.colorImage(image).asAttachment(size: .profileIconSize)
        let nameAttributedString = NSMutableAttributedString(
            string: "  " + name,
            attributes: [
                .font: NSFont.themeFont(fontSize),
                .baselineOffset: baselineOffset,
                .foregroundColor: self.color(.text)
            ]
        )
        return NSAttributedString.concatenate(imageAttributedString, nameAttributedString)
    }
}
