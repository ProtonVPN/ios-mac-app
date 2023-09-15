//
//  Created on 11/02/2022.
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

import Strings
import SwiftUI

public enum UpsellType {
    case netShield
    case secureCore
    case allCountries(numberOfServers: Int, numberOfCountries: Int)
    case country(countryFlag: Image, numberOfDevices: Int, numberOfCountries: Int)
    case safeMode
    case moderateNAT
    case noLogs
    case vpnAccelerator
    case customization
    case profiles
    case cantSkip(before: Date, duration: TimeInterval, longSkip: Bool)

    public func upsellFeature() -> UpsellFeature {
        UpsellFeature(
            title: title(),
            subtitle: subtitle(),
            boldSubtitleElements: boldSubtitleElements(),
            features: features(),
            moreInformation: moreInformation(),
            artImage: artImage()
        )
    }

    private func moreInformation() -> Feature? {
        switch self {
        case .noLogs:
            return .externalAudit
        default:
            return nil
        }
    }

    private func title() -> String {
        switch self {
        case .netShield:
            return Localizable.modalsUpsellNetShieldTitle
        case .secureCore:
            return Localizable.modalsUpsellSecureCoreTitle
        case .allCountries(let numberOfServers, let numberOfCountries):
            return Localizable.modalsUpsellAllCountriesTitle(numberOfServers, numberOfCountries)
        case .country:
            return Localizable.upsellCountryFeatureTitle
        case .safeMode:
            return Localizable.modalsUpsellSafeModeTitle
        case .moderateNAT:
            return Localizable.modalsUpsellModerateNatTitle
        case .noLogs:
            return Localizable.modalsNoLogsTitle
        case .vpnAccelerator:
            return Localizable.upsellVpnAcceleratorTitle
        case .customization:
            return Localizable.upsellCustomizationTitle
        case .profiles:
            return Localizable.upsellProfilesTitle
        case let .cantSkip(before, _, longSkip):
            if before.timeIntervalSinceNow > 0 && longSkip { // hide the title after timer runs out
                return Localizable.upsellCustomizationTitle
            }
            return ""
        }
    }

    private func subtitle() -> String? {
        switch self {
        case .netShield:
            return Localizable.modalsUpsellFeaturesSubtitle
        case .secureCore:
            return Localizable.modalsUpsellFeaturesSubtitle
        case .allCountries:
            return Localizable.modalsUpsellFeaturesSubtitle
        case .country:
            return Localizable.upsellCountryFeatureSubtitle
        case .safeMode:
            return Localizable.modalsUpsellFeaturesSafeModeSubtitle
        case .moderateNAT:
            return Localizable.modalsUpsellModerateNatSubtitle
        case .noLogs:
            return nil
        case .vpnAccelerator:
            return nil
        case .customization:
            return nil
        case .profiles:
            return Localizable.upsellProfilesSubtitle
        case let .cantSkip(before, _, _):
            if before.timeIntervalSinceNow > 0 { // hide the subtitle after timer runs out
                return Localizable.upsellSpecificLocationSubtitle
            }
            return nil
        }
    }

    private func boldSubtitleElements() -> [String] {
        switch self {
        case .profiles:
            return [Localizable.upsellProfilesSubtitleBold]
        case .country:
            return [Localizable.upsellCountryFeatureSubtitleBold]
        default:
            return []
        }
    }

    private func features() -> [Feature] {
        switch self {
        case .netShield:
            return [.blockAds, .protectFromMalware, .highSpeedNetshield]
        case .secureCore:
            return [.routeSecureServers, .addLayer, .protectFromAttacks]
        case .allCountries:
            return [.anyLocation, .higherSpeed, .geoblockedContent, .streaming]
        case .country(_, let numberOfDevices, let numberOfCountries):
            return [.multipleCountries(numberOfCountries), .higherSpeed, .streaming, .multipleDevices(numberOfDevices), .moneyGuarantee]
        case .safeMode:
            return []
        case .moderateNAT:
            return [.gaming, .directConnection]
        case .noLogs:
            return [.privacyFirst, .activityLogging, .noThirdParties]
        case .vpnAccelerator:
            return [.fasterServers, .increaseConnectionSpeeds, .distantServers]
        case .customization:
            return [.accessLAN, .profiles, .quickConnect]
        case .profiles:
            return [.location, .profilesProtocols, .autoConnect]
        case .cantSkip:
            return []
        }
    }

    public func artImage() -> any View {
        switch self {
        case .netShield:
#if os(iOS)
            return Asset.netshieldIOS.swiftUIImage
#else
            return Asset.netshieldMacOS.swiftUIImage
#endif
        case .secureCore:
            return Asset.secureCore.swiftUIImage
        case .allCountries:
            return Asset.plusCountries.swiftUIImage
        case .safeMode:
#if os(iOS)
            return Asset.safeModeIOS.swiftUIImage
#else
            return Asset.safeModeMacOS.swiftUIImage
#endif
        case .moderateNAT:
            return Asset.moderateNAT.swiftUIImage
        case .noLogs:
            return Asset.noLogs.swiftUIImage
        case .vpnAccelerator:
            return Asset.speed.swiftUIImage
        case .customization:
            return Asset.customisation.swiftUIImage
        case .profiles:
            return Asset.profiles.swiftUIImage
        case let .country(country, _, _):
            return ZStack {
                Asset.flatIllustration.swiftUIImage
                country.swiftUIImage
                    .resizable(resizingMode: .stretch)
                    .frame(width: 48, height: 48)
            }
        case let .cantSkip(beforeDate, timeInterval, _):
            return ReconnectCountdown(
                dateFinished: beforeDate,
                timeInterval: timeInterval
            )
        }
    }

    public var showUpgradeButton: Bool {
        switch self {
        case .noLogs:
            return false
        case let .cantSkip(until, _, _):
            return Date().timeIntervalSince(until) < 0
        default:
            return true
        }
    }

    public var changeDate: Date? {
        switch self {
        case let .cantSkip(until, _, _):
            return until
        default:
            return nil
        }
    }

    public func shouldAddGradient() -> Bool {
        switch self {
        case .noLogs:
            return false
        default:
            return true
        }
    }
}
