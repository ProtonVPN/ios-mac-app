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

#if os(macOS)
import AppKit
public typealias Image = NSImage
#else
import UIKit
public typealias Image = UIImage
#endif

public enum Feature {
    case streaming
    case multipleDevices(Int)
    case blockAds
    case protectFromMalware
    case highSpeedNetshield
    case routeSecureServers
    case addLayer
    case protectFromAttacks
    case privacyFirst
    case activityLogging
    case noThirdParties
    case externalAudit
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
        case .privacyFirst:
            return Localizable.modalsNoLogsPrivacyFirst
        case .activityLogging:
            return Localizable.modalsNoLogsLogActivity
        case .noThirdParties:
            return Localizable.modalsNoLogsThirdParties
        case .externalAudit:
            return Localizable.modalsNoLogsExternalAudit
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
            return Localizable.upsellCountriesBrowseFrom(countries)
        case .moneyGuarantee:
            return Localizable.upsellCountriesMoneyBack
        }
    }

    public var linkImage: Image? {
        switch self {
        case .externalAudit:
            return Theme.Asset.icArrowOutSquare.image
        default:
            return nil
        }
    }

    public var image: Image {
        switch self {
        case .streaming:
            return Asset.streamingIcon.image
        case .multipleDevices:
            return Asset.multipleDevicesIcon.image
        case .blockAds:
            return Asset.blockAds.image
        case .protectFromMalware:
            return Asset.netshieldIcon.image
        case .highSpeedNetshield:
            return Asset.highSpeedIcon.image
        case .routeSecureServers:
            return Asset.routeSecureServers.image
        case .addLayer:
            return Asset.addLayer.image
        case .protectFromAttacks:
            return Asset.protectFromAttacks.image
        case .privacyFirst, .activityLogging, .noThirdParties:
            return Asset.checkmarkCircle.image
        case .externalAudit:
            return Theme.Asset.icLightbulb.image
        case .gaming:
            return Theme.Asset.icMagicWand.image
        case .directConnection:
            return Theme.Asset.icArrowsLeftRight.image
        case .fasterServers:
            return Theme.Asset.icServers.image
        case .increaseConnectionSpeeds:
            return Theme.Asset.icBolt.image
        case .distantServers:
            return Theme.Asset.icChartLine.image
        case .accessLAN:
            return Theme.Asset.icPrinter.image
        case .profiles:
            return Theme.Asset.icPowerOff.image
        case .quickConnect:
            return Theme.Asset.icBolt.image
        case .location:
            return Theme.Asset.icGlobe.image
        case .profilesProtocols:
            return Theme.Asset.icSliders.image
        case .autoConnect:
            return Theme.Asset.icRocket.image
        case .anyLocation:
            return Theme.Asset.icGlobe.image
        case .higherSpeed:
            return Theme.Asset.icRocket.image
        case .geoblockedContent:
            return Theme.Asset.icLockOpen.image
        case .multipleCountries:
            return Theme.Asset.icGlobe.image
        case .moneyGuarantee:
            return Theme.Asset.icShieldFilled.image
        }
    }
}
