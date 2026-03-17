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

import Dependencies
import SharedViews
import Strings
import SwiftUI
import Theme

public enum UpsellModalType: Sendable, Equatable {
    case subscription
    case safeMode
    case netShield
    case secureCore
    case moderateNAT
    case profiles
    case vpnAccelerator
    case customization
    case streaming
    case p2pSupport
    case devices
    case torOverVPN
    case hermes
    case portForwarding
    case plutonium

    case allCountries(numberOfServers: Int, numberOfCountries: Int)
    case country(countryCode: String, numberOfDevices: Int, numberOfCountries: Int)
    case cantSkip(before: Date, totalDuration: TimeInterval, longSkip: Bool)
}

public extension UpsellModalType {
    struct Subtitle: Sendable, Equatable {
        public let text: String
        public let boldText: [String]

        public init(text: String, boldText: [String] = []) {
            self.text = text
            self.boldText = boldText
        }
    }

    var showUpgradeButton: Bool {
        switch self {
        case let .cantSkip(before, _, _):
            now.timeIntervalSince(before) < 0
        default:
            true
        }
    }

    var changeDate: Date? {
        switch self {
        case let .cantSkip(before, _, _):
            before
        default:
            nil
        }
    }

    var hasNewUpsellScreen: Bool {
        switch self {
        case .safeMode, .cantSkip:
            false
        default:
            true
        }
    }

    var title: String {
        switch self {
        case .subscription, .streaming:
            return Localizable.upsellPlansListTitle
        case .safeMode:
            return Localizable.modalsUpsellSafeModeTitle
        case .netShield:
            return Localizable.modalsNewUpsellNetshieldTitle
        // Localizable.modalsUpsellNetShieldTitle
        case .secureCore:
            return Localizable.modalsNewUpsellSecureCoreTitle
        case .moderateNAT:
            return Localizable.modalsUpsellModerateNatTitle
        case .allCountries:
            return Localizable.modalsNewUpsellAllCountriesTitle
        case .profiles:
            return Localizable.upsellProfilesTitle
        case .vpnAccelerator:
            return Localizable.modalsNewUpsellVpnAcceleratorTitle
        case .customization:
            return Localizable.upsellCustomizationTitle
        case .p2pSupport:
            return Localizable.upsellP2pSupportTitle
        case .devices:
            return Localizable.upsellDevicesTitle
        case .torOverVPN:
            return Localizable.upsellTorOverVPNTitle
        case .country:
            return Localizable.modalsNewUpsellCountryTitle
        case let .cantSkip(before, _, longSkip):
            if before.timeIntervalSince(now) > 0, longSkip {
                return Localizable.upsellCustomizationTitle
            }
            return ""
        case .hermes:
            return Localizable.hermesUpsellTitle
        case .portForwarding:
            return Localizable.upsellPfSupportTitle
        case .plutonium:
            return Localizable.plutoniumUpsellTitle
        }
    }

    var subtitle: String? {
        subtitleModel?.text
    }

    var subtitleModel: Subtitle? {
        switch self {
        case .subscription:
            return .init(text: Localizable.upsellPlansListSubtitle)
        case .safeMode:
            return .init(text: Localizable.modalsUpsellFeaturesSafeModeSubtitle)
        case .netShield:
            return .init(
                text: Localizable.modalsNewUpsellNetshieldSubtitle,
                boldText: [Localizable.modalsNewUpsellNetshieldSubtitleBold]
            )
        case .secureCore:
            return .init(
                text: Localizable.modalsNewUpsellSecureCoreSubtitle,
                boldText: [Localizable.modalsNewUpsellSecureCoreSubtitleBold]
            )
        case let .allCountries(numberOfServers, numberOfCountries):
            return .init(
                text: Localizable.modalsNewUpsellAllCountriesSubtitle(numberOfServers, numberOfCountries),
                boldText: [Localizable.modalsNewUpsellAllCountriesSubtitleBold]
            )
        case .profiles:
            return .init(
                text: Localizable.modalsNewUpsellProfilesSubtitle,
                boldText: [Localizable.upsellProfilesSubtitleBold1, Localizable.upsellProfilesSubtitleBold2]
            )
        case .vpnAccelerator:
            return .init(text: Localizable.modalsNewUpsellVpnAcceleratorSubtitle)
        case .customization:
            return .init(
                text: Localizable.modalsNewUpsellCustomizationSubtitle,
                boldText: [Localizable.upsellCustomizationAccessLANBold]
            )
        case .streaming:
            return .init(text: Localizable.upsellStreamingSubtitle)
        case .p2pSupport:
            return .init(text: Localizable.upsellP2pSupportSubtitle)
        case .devices:
            return .init(text: Localizable.upsellDevicesSubtitle)
        case .torOverVPN:
            return .init(text: Localizable.upsellTorOverVPNSubtitle)
        case .country:
            return .init(
                text: Localizable.modalsNewUpsellCountrySubtitle,
                boldText: [Localizable.upsellCountryFeatureSubtitleBold]
            )
        case let .cantSkip(before, _, _):
            if before.timeIntervalSince(now) > 0 {
                return .init(text: Localizable.upsellSpecificLocationSubtitle)
            }
            return nil
        case .moderateNAT:
            return .init(
                text: Localizable.modalsNewUpsellModerateNatSubtitle,
                boldText: [Localizable.modalsUpsellModerateNatSubtitleBold]
            )
        case .hermes:
            return .init(text: Localizable.hermesUpsellDescription)
        case .portForwarding:
            return .init(text: Localizable.upsellPfSupportSubtitle)
        case .plutonium:
            return .init(text: Localizable.plutoniumUpsellSubtitle)
        }
    }

    @MainActor @ViewBuilder
    func artImage() -> some View {
        switch self {
        case .subscription:
            Image(.welcomePlus)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .safeMode:
            Image(.safeMode)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .netShield:
            Image(.netshield)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .secureCore:
            Image(.secureCore)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .moderateNAT:
            Image(.moderateNAT)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .allCountries:
            Image(.plusCountries)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .profiles:
            Image(.profiles)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .vpnAccelerator:
            Image(.speed)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .customization:
            Image(.customisation)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .streaming:
            Image(.streaming)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .p2pSupport:
            Image(.p2P)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .devices:
            Image(.devices)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .torOverVPN:
            Image(.tor)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case let .country(countryCode, _, _):
            ZStack {
                Image(.flatIllustration)
                if let flag = ImageAsset.Image.flag(countryCode: countryCode) {
                    flag.swiftUIImage
                        .resizable(resizingMode: .stretch)
                        .frame(width: 48, height: 48)
                }
            }
        case let .cantSkip(before, totalDuration, _):
            ReconnectCountdown(
                dateFinished: before,
                totalDuration: totalDuration
            )
        case .hermes:
            Image(.hermes)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .portForwarding:
            Image(.portForwarding)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .plutonium:
            Image(.plutonium)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    func features() -> [UpsellFeature] {
        switch self {
        case .netShield:
            [.blockAds, .protectFromMalware, .highSpeedNetshield]
        case .secureCore:
            [.routeSecureServers, .addLayer, .protectFromAttacks]
        case .allCountries:
            [.anyLocation, .higherSpeed, .geoblockedContent, .streaming]
        case let .country(_, numberOfDevices, numberOfCountries):
            [
                .multipleCountries(numberOfCountries),
                .higherSpeed,
                .streaming,
                .multipleDevices(numberOfDevices),
                .moneyGuarantee,
            ]
        case .moderateNAT:
            [.gaming, .directConnection]
        case .vpnAccelerator:
            [.fasterServers, .increaseConnectionSpeeds, .distantServers]
        case .customization:
            [.accessLAN, .profiles, .quickConnect]
        case .profiles:
            [.location, .profilesProtocols, .autoConnect]
        case .safeMode, .streaming, .p2pSupport, .portForwarding, .devices, .torOverVPN, .hermes, .plutonium:
            []
        case .subscription:
            []
        case .cantSkip:
            []
        }
    }
}

private extension UpsellModalType {
    var now: Date {
        @Dependency(\.date.now) var now
        return now
    }
}
