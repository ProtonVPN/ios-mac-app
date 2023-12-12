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

// TODO: Change name, it's not only upsell now.
// TODO: Maybe change to a builder pattern, switching on so many cases is becoming tedious.
public enum UpsellType {
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

    public func primaryButtonTitle() -> String? {
        switch self {
        case .netShield:
            return Localizable.modalsUpsellNetShieldTitle
        case .welcomeToProton:
            return Localizable.modalsCommonGetStarted
        default:
            return Localizable.upgrade
        }
    }

    public func secondaryButtonTitle() -> String? {
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
        case .welcomePlus:
            return Localizable.welcomeUpgradeTitlePlus
        case .welcomeUnlimited:
            return Localizable.welcomeUpgradeTitleUnlimited
        case .welcomeFallback:
            return Localizable.welcomeUpgradeTitleFallback
        case .welcomeToProton:
            return Localizable.welcomeToProtonTitle
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
        case .welcomePlus:
            return Localizable.welcomeUpgradeSubtitlePlus
        case .welcomeUnlimited:
#if os(iOS)
            return Localizable.welcomeUpgradeSubtitleUnlimitedMarkdown
#else
            return Localizable.welcomeUpgradeSubtitleUnlimited
#endif
        case .welcomeFallback:
            return Localizable.welcomeUpgradeSubtitleFallback
        case .welcomeToProton:
            return Localizable.welcomeToProtonSubtitle
        }
    }

    private func boldSubtitleElements() -> [String] {
        switch self {
        case .profiles:
            return [Localizable.upsellProfilesSubtitleBold]
        case .country:
            return [Localizable.upsellCountryFeatureSubtitleBold]
        case .welcomeUnlimited:
            return [Localizable.welcomeUpgradeSubtitleUnlimitedBold]
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
        case .noLogs:
            Asset.noLogs.swiftUIImage
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
        }
    }

    public var showUpgradeButton: Bool {
        switch self {
        case .noLogs, .welcomeFallback, .welcomeUnlimited, .welcomePlus:
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
