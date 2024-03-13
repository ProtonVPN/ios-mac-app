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

    public func modalModel() -> ModalModel {
        ModalModel(
            title: title(),
            subtitle: subtitle(),
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

    private func subtitle() -> ModalModel.Subtitle? {
        switch self {
        case .netShield:
            return .init(text: Localizable.modalsUpsellFeaturesSubtitle, boldText: [])
        case .secureCore:
            return .init(text: Localizable.modalsUpsellFeaturesSubtitle, boldText: [])
        case .allCountries:
            return .init(text: Localizable.modalsUpsellFeaturesSubtitle, boldText: [])
        case .country:
            return .init(text: Localizable.upsellCountryFeatureSubtitle, 
                         boldText: [Localizable.upsellCountryFeatureSubtitleBold])
        case .safeMode:
            return .init(text: Localizable.modalsUpsellFeaturesSafeModeSubtitle, boldText: [])
        case .moderateNAT:
            return .init(text: Localizable.modalsUpsellModerateNatSubtitle, boldText: [])
        case .vpnAccelerator:
            return nil
        case .customization:
            return nil
        case .profiles:
            return .init(text: Localizable.upsellProfilesSubtitle, 
                         boldText: [Localizable.upsellProfilesSubtitleBold])
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
            return .init(text: Localizable.welcomeUpgradeSubtitleFallback, boldText: [])
        case .welcomeToProton:
            return .init(text: Localizable.welcomeToProtonSubtitle, boldText: [])
        case .subscription:
            return .init(text: Localizable.upsellPlansListSubtitle, boldText: [])
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
        case .secureCore:
            Asset.secureCore.swiftUIImage
        case .allCountries:
            Asset.plusCountries.swiftUIImage
        case .safeMode:
            Asset.safeMode.swiftUIImage
        case .moderateNAT:
            Asset.moderateNAT.swiftUIImage
        case .vpnAccelerator:
            Asset.speed.swiftUIImage
        case .customization:
            Asset.customisation.swiftUIImage
        case .profiles:
            Asset.profiles.swiftUIImage
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
}
