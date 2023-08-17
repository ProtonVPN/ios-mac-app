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
    case allCountries(numberOfDevices: Int, numberOfServers: Int, numberOfCountries: Int)
    case safeMode
    case moderateNAT
    case noLogs

    public func upsellFeature() -> UpsellFeature {
        UpsellFeature(title: title(),
                      subtitle: subtitle(),
                      features: features(),
                      moreInformation: moreInformation(),
                      artImage: artImage(),
                      footer: footer(),
                      learnMore: learnMore())
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
        case .allCountries(_, let numberOfServers, let numberOfCountries):
            return Localizable.modalsUpsellAllCountriesTitle(numberOfServers, numberOfCountries)
        case .safeMode:
            return Localizable.modalsUpsellSafeModeTitle
        case .moderateNAT:
            return Localizable.modalsUpsellModerateNatTitle
        case .noLogs:
            return Localizable.modalsNoLogsTitle
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
        case .safeMode:
            return Localizable.modalsUpsellFeaturesSafeModeSubtitle
        case .moderateNAT:
            return Localizable.modalsUpsellFeaturesModerateNatSubtitle
        case .noLogs:
            return nil
        }
    }

    private func features() -> [Feature] {
        switch self {
        case .netShield:
            return [.blockAds, .protectFromMalware, .highSpeedNetshield]
        case .secureCore:
            return [.routeSecureServers, .addLayer, .protectFromAttacks]
        case .allCountries(let numberOfDevices, _, _):
            return [.streaming, .multipleDevices(numberOfDevices), .netshield, .highSpeed]
        case .safeMode, .moderateNAT:
            return []
        case .noLogs:
            return [.privacyFirst, .activityLogging, .noThirdParties]
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
        }
    }

    private func footer() -> String? {
        switch self {
        case .allCountries:
            return Localizable.modalsUpsellFeaturesFooter
        default:
            return nil
        }
    }

    private func learnMore() -> String? {
        switch self {
        case .moderateNAT:
            return Localizable.modalsUpsellModerateNatLearnMore
        case .safeMode:
            return Localizable.modalsUpsellSafeModeLearnMore
        default:
            return nil
        }
    }
}
