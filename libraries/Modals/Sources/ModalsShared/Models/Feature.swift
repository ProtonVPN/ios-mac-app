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
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

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
    public enum ToggleID: Hashable, Identifiable {
        public var id: Self { self }

        case statistics
        case crashes
    }

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
    case toggle(id: ToggleID, title: String, subtitle: String, state: Bool)
}

extension Feature: Equatable {}

extension Feature {
    // swiftlint:disable:next cyclomatic_complexity
    public func title() -> String? {
        switch self {
        case .streaming:
            Localizable.modalsUpsellAllCountriesFeatureStreaming
        case let .multipleDevices(numberOfDevices):
            Localizable.modalsUpsellAllCountriesFeatureMultipleDevices(numberOfDevices)
        case .blockAds:
            Localizable.modalsUpsellNetShieldAds
        case .protectFromMalware:
            Localizable.modalsUpsellNetShieldMalware
        case .highSpeedNetshield:
            Localizable.modalsUpsellNetShieldHighSpeed
        case .routeSecureServers:
            Localizable.modalsUpsellSecureCoreRoute
        case .addLayer:
            Localizable.modalsUpsellSecureCoreLayer
        case .protectFromAttacks:
            Localizable.modalsUpsellSecureCoreAttacks
        case .gaming:
            Localizable.modalsUpsellFeaturesModerateNatGaming
        case .directConnection:
            Localizable.modalsUpsellFeaturesModerateNatDirectConnections
        case .fasterServers:
            Localizable.upsellVpnAcceleratorFasterServers
        case .increaseConnectionSpeeds:
            Localizable.upsellVpnAcceleratorIncreaseConnectionSpeeds
        case .distantServers:
            Localizable.upsellVpnAcceleratorDistantServers
        case .accessLAN:
            Localizable.upsellCustomizationAccessLAN
        case .profiles:
            Localizable.upsellCustomizationProfiles
        case .quickConnect:
            Localizable.upsellCustomizationQuickConnect
        case .location:
            Localizable.upsellProfilesFeatureLocation
        case .profilesProtocols:
            Localizable.upsellProfilesFeatureProtocols
        case .autoConnect:
            Localizable.upsellProfilesFeatureAutoConnect
        case .anyLocation:
            Localizable.upsellCountriesAnyLocation
        case .higherSpeed:
            Localizable.upsellCountriesHigherSpeeds
        case .geoblockedContent:
            Localizable.upsellCountriesGeoblockedContent
        case let .multipleCountries(countries):
            Localizable.upsellCountriesConnectTo(countries)
        case .moneyGuarantee:
            Localizable.upsellCountriesMoneyBack
        case let .welcomeNewServersCountries(servers, countries):
            Localizable.welcomeScreenFeatureServersCountries(servers, countries)
        case .welcomeAdvancedFeatures:
            Localizable.welcomeUpgradeAdvancedFeatures
        case let .welcomeDevices(devices):
            Localizable.welcomeScreenFeatureDevices(devices)
        case .banner:
            nil
        case .toggle:
            nil
        }
    }

    public func boldTitleElements() -> [String] {
        switch self {
        case .gaming:
            [Localizable.modalsUpsellModerateNatSubtitleBold]
        case .increaseConnectionSpeeds:
            [Localizable.upsellVpnAcceleratorIncreaseConnectionSpeedsBold]
        case .profiles:
            [Localizable.upsellCustomizationProfilesBold]
        case .quickConnect:
            [Localizable.upsellCustomizationQuickConnectBold]
        case .accessLAN:
            [Localizable.upsellCustomizationAccessLANBold]
        default:
            []
        }
    }

    public var image: Image? {
        switch self {
        case .streaming:
            IconProvider.play
        case .multipleDevices:
            IconProvider.locks
        case .blockAds:
            IconProvider.circleSlash
        case .protectFromMalware:
            IconProvider.shield
        case .highSpeedNetshield:
            IconProvider.rocket
        case .routeSecureServers:
            IconProvider.servers
        case .addLayer:
            IconProvider.locks
        case .protectFromAttacks:
            IconProvider.alias
        case .gaming:
            IconProvider.magicWand
        case .directConnection:
            IconProvider.arrowsLeftRight
        case .fasterServers:
            IconProvider.servers
        case .increaseConnectionSpeeds:
            IconProvider.bolt
        case .distantServers:
            IconProvider.chartLine
        case .accessLAN:
            IconProvider.printer
        case .profiles:
            IconProvider.powerOff
        case .quickConnect:
            IconProvider.bolt
        case .location:
            IconProvider.globe
        case .profilesProtocols:
            IconProvider.sliders
        case .autoConnect:
            IconProvider.rocket
        case .anyLocation:
            IconProvider.globe
        case .higherSpeed:
            IconProvider.rocket
        case .geoblockedContent:
            IconProvider.lockOpen
        case .multipleCountries:
            IconProvider.globe
        case .moneyGuarantee:
            IconProvider.shieldFilled
        case .welcomeNewServersCountries:
            IconProvider.globe
        case .welcomeAdvancedFeatures:
            IconProvider.sliders
        case .welcomeDevices:
            IconProvider.locks
        case .banner:
            IconProvider.play
        case .toggle:
            nil
        }
    }
}
