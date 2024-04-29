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

// TODO: Separate `cantSkip` from the rest, it's different enough to be on it's own.
public enum ModalType {
    case netShield
    case secureCore
    case allCountries(numberOfServers: Int, numberOfCountries: Int)
    case country(countryFlag: Image, numberOfDevices: Int, numberOfCountries: Int)
    case welcomePlus(numberOfServers: Int, numberOfDevices: Int, numberOfCountries: Int)
    case welcomeUnlimited
    case welcomeFallback
    case welcomeToProton
    case safeMode
    case moderateNAT
    case vpnAccelerator
    case customization
    case profiles
    case cantSkip(before: Date, duration: TimeInterval, longSkip: Bool)
    case subscription

    public func modalModel(legacy: Bool = false) -> ModalModel {
        ModalModel(
            title: title(legacy: legacy),
            subtitle: subtitle(legacy: legacy),
            features: features(),
            primaryButtonTitle: primaryButtonTitle(),
            secondaryButtonTitle: secondaryButtonTitle(),
            shouldAddGradient: shouldAddGradient()
        )
    }

    private func primaryButtonTitle() -> String {
        switch self {
        case .netShield:
            return Localizable.modalsUpsellNetShieldTitle
        case .welcomeToProton, .welcomeFallback, .welcomeUnlimited, .welcomePlus:
            return Localizable.modalsCommonGetStarted
        default:
            return Localizable.upgrade
        }
    }

    private func secondaryButtonTitle() -> String? {
        return Localizable.notNow
    }

    private func title(legacy: Bool) -> String {
        switch self {
        case .netShield:
            return legacy ? Localizable.modalsUpsellNetShieldTitle : Localizable.modalsNewUpsellNetshieldTitle
        case .secureCore:
            return legacy ? Localizable.modalsUpsellSecureCoreTitle : Localizable.modalsNewUpsellSecureCoreTitle
        case .allCountries(let numberOfServers, let numberOfCountries):
            return legacy ?
                Localizable.modalsUpsellAllCountriesTitle(numberOfServers, numberOfCountries) :
                Localizable.modalsNewUpsellAllCountriesTitle
        case .country:
            return legacy ? Localizable.upsellCountryFeatureTitle : Localizable.modalsNewUpsellCountryTitle
        case .safeMode:
            return Localizable.modalsUpsellSafeModeTitle
        case .moderateNAT:
            return Localizable.modalsUpsellModerateNatTitle
        case .vpnAccelerator:
            return legacy ? Localizable.upsellVpnAcceleratorTitle : Localizable.modalsNewUpsellVpnAcceleratorTitle
        case .customization:
            return Localizable.upsellCustomizationTitle
        case .profiles:
            return Localizable.upsellProfilesTitle
        case let .cantSkip(before, _, longSkip):
            if before.timeIntervalSinceNow > 0 && longSkip { // hide the title after timer runs out
                return Localizable.upsellCustomizationTitle
            }
            return ""
        case .welcomePlus:
            return Localizable.welcomeUpgradeTitlePlus
        case .welcomeUnlimited:
            return Localizable.welcomeUpgradeTitleUnlimited
        case .welcomeFallback:
            return Localizable.welcomeUpgradeTitleFallback
        case .welcomeToProton:
            return Localizable.welcomeToProtonTitle
        case .subscription:
            return Localizable.upsellPlansListTitle
        }
    }

    private func subtitle(legacy: Bool) -> ModalModel.Subtitle? {
        switch self {
        case .netShield:
            return .init(
                text: legacy ? Localizable.modalsUpsellFeaturesSubtitle : Localizable.modalsNewUpsellNetshieldSubtitle,
                boldText: legacy ? [] : [Localizable.modalsNewUpsellNetshieldSubtitleBold]
            )
        case .secureCore:
            return .init(
                text: legacy ? Localizable.modalsUpsellFeaturesSubtitle : Localizable.modalsNewUpsellSecureCoreSubtitle,
                boldText: legacy ? [] : [Localizable.modalsNewUpsellSecureCoreSubtitleBold])
        case .allCountries(let numberOfServers, let numberOfCountries):
            let text = legacy ?
                Localizable.modalsUpsellFeaturesSubtitle :
                Localizable.modalsNewUpsellAllCountriesSubtitle(numberOfServers, numberOfCountries)
            return .init(text: text, boldText: legacy ? [] : [Localizable.modalsNewUpsellAllCountriesSubtitleBold])
        case .country:
            return .init(
                text: legacy ? Localizable.upsellCountryFeatureSubtitle : Localizable.modalsNewUpsellCountrySubtitle,
                boldText: legacy ? [] : [Localizable.upsellCountryFeatureSubtitleBold]
            )
        case .safeMode:
            return .init(text: Localizable.modalsUpsellFeaturesSafeModeSubtitle)
        case .moderateNAT:
            return .init(
                text: legacy ? Localizable.modalsUpsellModerateNatSubtitle : Localizable.modalsNewUpsellModerateNatSubtitle,
                boldText: [Localizable.modalsUpsellModerateNatSubtitleBold]
            )
        case .vpnAccelerator:
            return legacy ? nil : .init(text: Localizable.modalsNewUpsellVpnAcceleratorSubtitle)
        case .customization:
            return legacy ? nil : .init(
                text: Localizable.modalsNewUpsellCustomizationSubtitle,
                boldText: [Localizable.upsellCustomizationAccessLANBold]
            )
        case .profiles:
            return .init(
                text: legacy ? Localizable.upsellProfilesSubtitle : Localizable.modalsNewUpsellProfilesSubtitle,
                boldText: [Localizable.upsellProfilesSubtitleBold1].appending(legacy ? [] : [Localizable.upsellProfilesSubtitleBold2])
            )
        case let .cantSkip(before, _, _):
            if before.timeIntervalSinceNow > 0 { // hide the subtitle after timer runs out
                return .init(text: Localizable.upsellSpecificLocationSubtitle, boldText: [])
            }
            return nil
        case .welcomePlus:
            return .init(text: Localizable.welcomeUpgradeSubtitlePlus, boldText: [])
        case .welcomeUnlimited:
#if os(iOS)
            return .init(text: Localizable.welcomeUpgradeSubtitleUnlimitedMarkdown, 
                         boldText: [Localizable.welcomeUpgradeSubtitleUnlimitedBold])
#else
            return .init(text: Localizable.welcomeUpgradeSubtitleUnlimited, boldText: [])
#endif
        case .welcomeFallback:
            return .init(text: Localizable.welcomeUpgradeSubtitleFallback)
        case .welcomeToProton:
            return .init(text: Localizable.welcomeToProtonSubtitle)
        case .subscription:
            return .init(text: Localizable.upsellPlansListSubtitle)
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
        case let .country(_, numberOfDevices, numberOfCountries):
            return [
                .multipleCountries(numberOfCountries),
                .higherSpeed,
                .streaming,
                .multipleDevices(numberOfDevices),
                .moneyGuarantee]
        case .safeMode:
            return []
        case .moderateNAT:
            return [.gaming, .directConnection]
        case .vpnAccelerator:
            return [.fasterServers, .increaseConnectionSpeeds, .distantServers]
        case .customization:
            return [.accessLAN, .profiles, .quickConnect]
        case .profiles:
            return [.location, .profilesProtocols, .autoConnect]
        case .cantSkip:
            return []
        case let .welcomePlus(numberOfServers, numberOfDevices, numberOfCountries):
            return [
                .welcomeNewServersCountries(numberOfServers, numberOfCountries),
                .welcomeAdvancedFeatures,
                .welcomeDevices(numberOfDevices)
            ]
        case .welcomeUnlimited:
            return []
        case .welcomeFallback:
            return []
        case .welcomeToProton:
            return [.banner]
        case .subscription:
            return []
        }
    }

    @ViewBuilder
    public func artImage() -> some View {
        switch self {
        case .netShield:
            Asset.netshield.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .secureCore:
            Asset.secureCore.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .allCountries:
            Asset.plusCountries.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .safeMode:
            Asset.safeMode.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .moderateNAT:
            Asset.moderateNAT.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .vpnAccelerator:
            Asset.speed.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .customization:
            Asset.customisation.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .profiles:
            Asset.profiles.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        case let .country(country, _, _):
            ZStack {
                Asset.flatIllustration.swiftUIImage
                country.swiftUIImage
                    .resizable(resizingMode: .stretch)
                    .frame(width: 48, height: 48)
            }
        case let .cantSkip(beforeDate, timeInterval, _):
            ReconnectCountdown(
                dateFinished: beforeDate,
                timeInterval: timeInterval
            )
        case .welcomePlus:
            Asset.welcomePlus.swiftUIImage
        case .welcomeUnlimited:
            Asset.welcomeUnlimited.swiftUIImage
        case .welcomeFallback:
            Asset.welcomeFallback.swiftUIImage
        case .welcomeToProton:
            Asset.welcome.swiftUIImage
        case .subscription:
            Asset.welcomePlus.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    public var showUpgradeButton: Bool {
        switch self {
        case .welcomeFallback, .welcomeUnlimited, .welcomePlus:
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

    private func shouldAddGradient() -> Bool {
        switch self {
        default:
            return true
        }
    }

    public var hasNewUpsellScreen: Bool {
        switch self {
        case .profiles, .country, .netShield, .vpnAccelerator, .moderateNAT, .customization, .allCountries, .secureCore, .subscription:
            return true
        case .welcomePlus, .welcomeUnlimited, .welcomeFallback, .welcomeToProton, .safeMode, .cantSkip:
            return false
        }
    }
}
