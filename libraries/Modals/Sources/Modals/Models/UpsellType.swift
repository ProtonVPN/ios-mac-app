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

    public func upsellFeature() -> UpsellFeature {
        UpsellFeature(title: title(),
                      subtitle: subtitle(),
                      features: features(),
                      moreInformation: moreInformation(),
                      artImage: artImage(),
                      flagImage: flagImage())
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
        case .country(let country, _, _):
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
        }
    }

    private func artImage() -> Image {
        switch self {
        case .netShield:
#if os(iOS)
            return Asset.netshieldIOS.image
#else
            return Asset.netshieldMacOS.image
#endif
        case .secureCore:
            return Asset.secureCore.image
        case .allCountries:
            return Asset.plusCountries.image
        case .safeMode:
#if os(iOS)
            return Asset.safeModeIOS.image
#else
            return Asset.safeModeMacOS.image
#endif
        case .moderateNAT:
            return Asset.moderateNAT.image
        case .noLogs:
            return Asset.noLogs.image
        case .vpnAccelerator:
            return Asset.speed.image
        case .customization:
            return Asset.customisation.image
        case .profiles:
            return Asset.profiles.image
        case .country:
            return Asset.flatIllustration.image
        }
    }

    private func flagImage() -> Image? {
        switch self {
        case .country(let country, _, _):
            return country
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
