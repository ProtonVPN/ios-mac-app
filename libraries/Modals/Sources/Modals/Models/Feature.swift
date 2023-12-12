//
//  Created on 2/8/22.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import Strings
import Theme
import SwiftUI
import ProtonCoreUIFoundations

#if os(macOS)
import AppKit
public typealias Image = NSImage

public extension Image {
    var swiftUIImage: SwiftUI.Image {
        SwiftUI.Image(nsImage: self)
    }
}
#else
import UIKit
public typealias Image = UIImage

public extension Image {
    var swiftUIImage: SwiftUI.Image {
        SwiftUI.Image(uiImage: self)
    }
}
#endif

public enum Feature: Hashable, Identifiable {
    public var id: Self { self }

    case streaming
    case multipleDevices(Int)
    case blockAds
    case protectFromMalware
    case highSpeedNetshield
    case routeSecureServers
    case addLayer
    case protectFromAttacks
    case gaming
    case directConnection
    case fasterServers
    case increaseConnectionSpeeds
    case distantServers
    case accessLAN
    case profiles
    case quickConnect
    case location
    case profilesProtocols
    case autoConnect
    case anyLocation
    case higherSpeed
    case geoblockedContent
    case multipleCountries(Int)
    case moneyGuarantee
    case welcomeNewServersCountries(Int, Int)
    case welcomeAdvancedFeatures
    case welcomeDevices(Int)
    case banner
}

extension Feature: Equatable { }

extension Feature {
    // swiftlint:disable:next cyclomatic_complexity
    public func title() -> String {
        switch self {
        case .streaming:
            return Localizable.modalsUpsellAllCountriesFeatureStreaming
        case .multipleDevices(let numberOfDevices):
            return Localizable.modalsUpsellAllCountriesFeatureMultipleDevices(numberOfDevices)
        case .blockAds:
            return Localizable.modalsUpsellNetShieldAds
        case .protectFromMalware:
            return Localizable.modalsUpsellNetShieldMalware
        case .highSpeedNetshield:
            return Localizable.modalsUpsellNetShieldHighSpeed
        case .routeSecureServers:
            return Localizable.modalsUpsellSecureCoreRoute
        case .addLayer:
            return Localizable.modalsUpsellSecureCoreLayer
        case .protectFromAttacks:
            return Localizable.modalsUpsellSecureCoreAttacks
        case .gaming:
            return Localizable.modalsUpsellFeaturesModerateNatGaming
        case .directConnection:
            return Localizable.modalsUpsellFeaturesModerateNatDirectConnections
        case .fasterServers:
            return Localizable.upsellVpnAcceleratorFasterServers
        case .increaseConnectionSpeeds:
            return Localizable.upsellVpnAcceleratorIncreaseConnectionSpeeds
        case .distantServers:
            return Localizable.upsellVpnAcceleratorDistantServers
        case .accessLAN:
            return Localizable.upsellCustomizationAccessLAN
        case .profiles:
            return Localizable.upsellCustomizationProfiles
        case .quickConnect:
            return Localizable.upsellCustomizationQuickConnect
        case .location:
            return Localizable.upsellProfilesFeatureLocation
        case .profilesProtocols:
            return Localizable.upsellProfilesFeatureProtocols
        case .autoConnect:
            return Localizable.upsellProfilesFeatureAutoConnect
        case .anyLocation:
            return Localizable.upsellCountriesAnyLocation
        case .higherSpeed:
            return Localizable.upsellCountriesHigherSpeeds
        case .geoblockedContent:
            return Localizable.upsellCountriesGeoblockedContent
        case .multipleCountries(let countries):
            return Localizable.upsellCountriesConnectTo(countries)
        case .moneyGuarantee:
            return Localizable.upsellCountriesMoneyBack
        case let .welcomeNewServersCountries(servers, countries):
            return Localizable.welcomeScreenFeatureServersCountries(servers, countries)
        case .welcomeAdvancedFeatures:
            return Localizable.welcomeUpgradeAdvancedFeatures
        case .welcomeDevices(let devices):
            return Localizable.welcomeScreenFeatureDevices(devices)
        case .banner:
            return ""
        }
    }

    public func boldTitleElements() -> [String] {
        switch self {
        case .gaming:
            return [Localizable.modalsUpsellModerateNatSubtitleBold]
        case .increaseConnectionSpeeds:
            return [Localizable.upsellVpnAcceleratorIncreaseConnectionSpeedsBold]
        case .profiles:
            return [Localizable.upsellCustomizationProfilesBold]
        case .quickConnect:
            return [Localizable.upsellCustomizationQuickConnectBold]
        case .accessLAN:
            return [Localizable.upsellCustomizationAccessLANBold]
        default:
            return []
        }
    }

    public var image: Image {
        switch self {
        case .streaming:
            return IconProvider.play
        case .multipleDevices:
            return IconProvider.locks
        case .blockAds:
            return IconProvider.circleSlash
        case .protectFromMalware:
            return IconProvider.shield
        case .highSpeedNetshield:
            return IconProvider.rocket
        case .routeSecureServers:
            return IconProvider.servers
        case .addLayer:
            return IconProvider.locks
        case .protectFromAttacks:
            return IconProvider.alias
        case .gaming:
            return IconProvider.magicWand
        case .directConnection:
            return IconProvider.arrowsLeftRight
        case .fasterServers:
            return IconProvider.servers
        case .increaseConnectionSpeeds:
            return IconProvider.bolt
        case .distantServers:
            return IconProvider.chartLine
        case .accessLAN:
            return IconProvider.printer
        case .profiles:
            return IconProvider.powerOff
        case .quickConnect:
            return IconProvider.bolt
        case .location:
            return IconProvider.globe
        case .profilesProtocols:
            return IconProvider.sliders
        case .autoConnect:
            return IconProvider.rocket
        case .anyLocation:
            return IconProvider.globe
        case .higherSpeed:
            return IconProvider.rocket
        case .geoblockedContent:
            return IconProvider.lockOpen
        case .multipleCountries:
            return IconProvider.globe
        case .moneyGuarantee:
            return IconProvider.shieldFilled
        case .welcomeNewServersCountries:
            return IconProvider.globe
        case .welcomeAdvancedFeatures:
            return IconProvider.sliders
        case .welcomeDevices:
            return IconProvider.locks
        case .banner:
            return IconProvider.play
        }
    }
}
