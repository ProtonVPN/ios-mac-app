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

public enum UpsellType {
    case netShield
    case secureCore
    case allCountries(numberOfDevices: Int, numberOfServers: Int, numberOfCountries: Int)
    case safeMode
    case moderateNAT

    public func upsellFeature() -> UpsellFeature {
        switch self {
        case .netShield:
            let title = LocalizedString.modalsUpsellNetShieldTitle
            let subtitle = LocalizedString.modalsUpsellFeaturesSubtitle
            let features: [Feature] = [.blockAds, .protectFromMalware, .highSpeedNetshield]
#if os(iOS)
            let artImage = Asset.netshieldIOS.image
#else
            let artImage = Asset.netshieldMacOS.image
#endif
            return UpsellFeature(title: title, subtitle: subtitle, features: features, artImage: artImage, footer: nil)
        case .secureCore:
            let title = LocalizedString.modalsUpsellSecureCoreTitle
            let subtitle = LocalizedString.modalsUpsellFeaturesSubtitle
            let features: [Feature] = [.routeSecureServers, .addLayer, .protectFromAttacks]
            let artImage = Asset.secureCore.image
            return UpsellFeature(title: title, subtitle: subtitle, features: features, artImage: artImage, footer: nil)
        case .allCountries(let numberOfDevices, let numberOfServers, let numberOfCountries):
            let title = LocalizedString.modalsUpsellAllCountriesTitle(numberOfServers, numberOfCountries)
            let subtitle = LocalizedString.modalsUpsellFeaturesSubtitle
            let features: [Feature] = [.streaming, .multipleDevices(numberOfDevices), .netshield, .highSpeed]
            let artImage = Asset.plusCountries.image
            let footer = LocalizedString.modalsUpsellFeaturesFooter
            return UpsellFeature(title: title, subtitle: subtitle, features: features, artImage: artImage, footer: footer)
        case .safeMode:
            let title = LocalizedString.modalsUpsellSafeModeTitle
            let subtitle = LocalizedString.modalsUpsellFeaturesSafeModeSubtitle
#if os(iOS)
            let artImage = Asset.safeModeIOS.image
#else
            let artImage = Asset.safeModeMacOS.image
#endif
            return UpsellFeature(title: title, subtitle: subtitle, features: [], artImage: artImage, footer: nil)
        case .moderateNAT:
            let title = LocalizedString.modalsUpsellModerateNatTitle
            let subtitle = LocalizedString.modalsUpsellFeaturesModerateNatSubtitle
            let artImage = Asset.moderateNAT.image
            return UpsellFeature(title: title, subtitle: subtitle, features: [], artImage: artImage, footer: nil)
        }
    }
}
