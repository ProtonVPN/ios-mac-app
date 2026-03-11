//
//  Created on 06/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Strings
import SwiftUI
import Theme

public enum UpsellFeature: Hashable, Identifiable, Equatable {
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
}

public extension UpsellFeature {
    func title() -> String {
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
        }
    }

    func boldTitleElements() -> [String] {
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

    var image: Theme.ImageAsset.Image? {
        switch self {
        case .streaming:
            Theme.Asset.Icons.play.image
        case .multipleDevices:
            Theme.Asset.Icons.locks.image
        case .blockAds:
            Theme.Asset.Icons.circleSlash.image
        case .protectFromMalware:
            Theme.Asset.Icons.shield.image
        case .highSpeedNetshield:
            Theme.Asset.Icons.rocket.image
        case .routeSecureServers:
            Theme.Asset.Icons.servers.image
        case .addLayer:
            Theme.Asset.Icons.locks.image
        case .protectFromAttacks:
            Theme.Asset.Icons.alias.image
        case .gaming:
            Theme.Asset.Icons.magicWand.image
        case .directConnection:
            Theme.Asset.Icons.arrowsLeftRight.image
        case .fasterServers:
            Theme.Asset.Icons.servers.image
        case .increaseConnectionSpeeds:
            Theme.Asset.Icons.bolt.image
        case .distantServers:
            Theme.Asset.Icons.chartLine.image
        case .accessLAN:
            Theme.Asset.Icons.printer.image
        case .profiles:
            Theme.Asset.Icons.powerOff.image
        case .quickConnect:
            Theme.Asset.Icons.bolt.image
        case .location:
            Theme.Asset.Icons.globe.image
        case .profilesProtocols:
            Theme.Asset.Icons.sliders.image
        case .autoConnect:
            Theme.Asset.Icons.rocket.image
        case .anyLocation:
            Theme.Asset.Icons.globe.image
        case .higherSpeed:
            Theme.Asset.Icons.rocket.image
        case .geoblockedContent:
            Theme.Asset.Icons.lockOpen.image
        case .multipleCountries:
            Theme.Asset.Icons.globe.image
        case .moneyGuarantee:
            Theme.Asset.Icons.shieldFilled.image
        }
    }
}
