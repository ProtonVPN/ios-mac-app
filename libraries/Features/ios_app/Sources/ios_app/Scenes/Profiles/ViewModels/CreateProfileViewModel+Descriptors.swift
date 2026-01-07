//
//  CreateProfileViewModel+Descriptors.swift
//  ProtonVPN - Created on 01.07.19.
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

import CommonNetworking
import Domain
import Foundation
import LegacyCommon
import Localization
import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import Strings
import UIKit

extension CreateOrEditProfileViewModel {
    private var fontSize: CGFloat {
        17
    }

    private var baselineOffset: CGFloat {
        4
    }

    // MARK: - Country / Gateway

    func countryDescriptor(for group: ServerGroupInfo) -> NSAttributedString {
        let imageAttributedString: NSAttributedString
        let countryString: String

        switch group.kind {
        case let .country(countryCode):
            imageAttributedString = embeddedCountryFlag(countryCode: countryCode)
            countryString = "  " + (LocalizationUtility.default.countryName(forCode: countryCode) ?? "")
        case let .gateway(name):
            imageAttributedString = embeddedImageIcon(image: IconProvider.servers)
            countryString = "  " + name
        case let .city(name, code):
            imageAttributedString = embeddedCountryFlag(countryCode: code)
            countryString = "  " + name
            log.assertionFailure("Unexpected server group kind")
        case let .state(name, code):
            imageAttributedString = embeddedCountryFlag(countryCode: code)
            countryString = "  " + name
            log.assertionFailure("Unexpected server group kind")
        }

        let nameAttributedString: NSAttributedString = if group.minTier <= userTier {
            NSMutableAttributedString(
                string: countryString,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: UIColor.normalTextColor(),
                ]
            )
        } else {
            NSMutableAttributedString(
                string: countryString + " (\(Localizable.upgradeRequired))",
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: UIColor.weakTextColor(),
                ]
            )
        }
        return NSAttributedString.concatenate(imageAttributedString, nameAttributedString)
    }

    // MARK: - Server

    func serverDescriptor(for server: ServerModel) -> NSAttributedString {
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

    func serverDescriptor(for server: ServerInfo) -> NSAttributedString {
        server.logical.feature.contains(.secureCore)
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
            string: "\(Localizable.via)  ",
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
                .baselineOffset: baselineOffset,
                .foregroundColor: UIColor.normalTextColor(),
            ]
        )
        let entryCountryFlag = embeddedCountryFlag(countryCode: entryCountryCode)
        let entryCountry = NSMutableAttributedString(
            string: "  " + entryCountry,
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
                .baselineOffset: baselineOffset,
                .foregroundColor: UIColor.normalTextColor(),
            ]
        )
        return NSAttributedString.concatenate(via, entryCountryFlag, entryCountry)
    }

    private func serverDescriptorForStandard(serverName: String, countryCode: String, serverTier: Int) -> NSAttributedString {
        let countryFlag = embeddedCountryFlag(countryCode: countryCode)
        let serverString = "  " + serverName
        let serverDescriptor: NSAttributedString = if serverTier <= userTier {
            NSMutableAttributedString(
                string: serverString,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: UIColor.normalTextColor(),
                ]
            )
        } else {
            NSMutableAttributedString(
                string: serverString + " (\(Localizable.upgradeRequired))",
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .baselineOffset: baselineOffset,
                    .foregroundColor: UIColor.weakTextColor(),
                ]
            )
        }
        return NSAttributedString.concatenate(countryFlag, serverDescriptor)
    }

    // MARK: - Pre-set

    func defaultServerDescriptor(forIndex index: Int) -> NSAttributedString {
        let image: UIImage
        let name: String

        switch index {
        case 0:
            image = IconProvider.bolt
            name = Localizable.fastest
        default:
            image = IconProvider.arrowsSwapRight
            name = Localizable.random
        }

        let imageAttributedString = NSMutableAttributedString(attributedString: NSAttributedString.imageAttachment(image: image, size: CGSize(width: 24, height: 24)))
        let nameAttributedString = NSMutableAttributedString(
            string: "  " + name,
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
                .baselineOffset: baselineOffset,
            ]
        )
        nameAttributedString.insert(imageAttributedString, at: 0)

        return nameAttributedString
    }

    // MARK: - Icon

    private func embeddedImageIcon(image: UIImage?, baselineOffset: CGFloat? = nil, size: CGSize = CGSize(width: 18, height: 18)) -> NSAttributedString {
        if let image {
            return NSAttributedString.imageAttachment(image: image, baselineOffset: baselineOffset, size: size)
        }
        return NSAttributedString(string: "")
    }

    private func embeddedCountryFlag(countryCode: String) -> NSAttributedString {
        let image = UIImage.flag(countryCode: countryCode)
        let size = CGSize(width: 18, height: 12)
        return embeddedImageIcon(
            image: roundedCroppedImage(image: image, targetSize: size, cornerRadius: 2.4), // The corner radius value is proportionally aligned with the flags in the country list.
            baselineOffset: 3,
            size: size
        )
    }

    private func roundedCroppedImage(image: UIImage?, targetSize: CGSize, cornerRadius: CGFloat) -> UIImage? {
        guard let image else {
            return nil
        }

        let aspectFillScale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let scaledSize = CGSize(width: image.size.width * aspectFillScale, height: image.size.height * aspectFillScale)
        let origin = CGPoint(x: (targetSize.width - scaledSize.width) / 2, y: (targetSize.height - scaledSize.height) / 2)

        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            if cornerRadius > 0 {
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: targetSize), cornerRadius: cornerRadius).addClip()
            }
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
