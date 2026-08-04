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
import Domain
import Persistence
import SharedViews
import Strings
import SwiftUI
import Theme

public enum UpsellModalType: Sendable, Equatable {
    case subscription
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

    case allCountries
    case country(countryCode: String)
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
        @Dependency(\.date) var date

        return switch self {
        case let .cantSkip(before, _, _):
            date.now.timeIntervalSince(before) < 0
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
        case .cantSkip:
            false
        default:
            true
        }
    }

    var title: String {
        @Dependency(\.date) var date

        return switch self {
        case .subscription, .streaming:
            Localizable.upsellPlansListTitle
        case .netShield:
            Localizable.modalsNewUpsellNetshieldTitle
        // Localizable.modalsUpsellNetShieldTitle
        case .secureCore:
            Localizable.modalsNewUpsellSecureCoreTitle
        case .moderateNAT:
            Localizable.modalsUpsellModerateNatTitle
        case .allCountries:
            Localizable.modalsNewUpsellAllCountriesTitle
        case .profiles:
            Localizable.upsellProfilesTitle
        case .vpnAccelerator:
            Localizable.modalsNewUpsellVpnAcceleratorTitle
        case .customization:
            Localizable.upsellCustomizationTitle
        case .p2pSupport:
            Localizable.upsellP2pSupportTitle
        case .devices:
            Localizable.upsellDevicesTitle
        case .torOverVPN:
            Localizable.upsellTorOverVPNTitle
        case .country:
            Localizable.modalsNewUpsellCountryTitle
        case let .cantSkip(before, _, longSkip):
            if before.timeIntervalSince(date.now) > 0, longSkip {
                Localizable.upsellCustomizationTitle
            } else {
                ""
            }
        case .hermes:
            Localizable.hermesUpsellTitle
        case .portForwarding:
            Localizable.upsellPfSupportTitle
        case .plutonium:
            Localizable.plutoniumUpsellTitle
        }
    }

    var subtitle: String? {
        subtitleModel?.text
    }

    var subtitleModel: Subtitle? {
        @Dependency(\.serverRepository) var serverRepository
        @Dependency(\.date) var date

        return switch self {
        case .subscription:
            .init(text: Localizable.upsellPlansListSubtitle)
        case .netShield:
            .init(
                text: Localizable.modalsNewUpsellNetshieldSubtitle,
                boldText: [Localizable.modalsNewUpsellNetshieldSubtitleBold]
            )
        case .secureCore:
            .init(
                text: Localizable.modalsNewUpsellSecureCoreSubtitle,
                boldText: [Localizable.modalsNewUpsellSecureCoreSubtitleBold]
            )
        case .allCountries:
            .init(
                text: Localizable.modalsNewUpsellAllCountriesSubtitle(
                    serverRepository.roundedServerCount,
                    serverRepository.countryCount()
                ),
                boldText: [Localizable.modalsNewUpsellAllCountriesSubtitleBold]
            )
        case .profiles:
            .init(
                text: Localizable.modalsNewUpsellProfilesSubtitle,
                boldText: [Localizable.upsellProfilesSubtitleBold1, Localizable.upsellProfilesSubtitleBold2]
            )
        case .vpnAccelerator:
            .init(text: Localizable.modalsNewUpsellVpnAcceleratorSubtitle)
        case .customization:
            .init(
                text: Localizable.modalsNewUpsellCustomizationSubtitle,
                boldText: [Localizable.upsellCustomizationAccessLANBold]
            )
        case .streaming:
            .init(text: Localizable.upsellStreamingSubtitle)
        case .p2pSupport:
            .init(text: Localizable.upsellP2pSupportSubtitle)
        case .devices:
            .init(text: Localizable.upsellDevicesSubtitle)
        case .torOverVPN:
            .init(text: Localizable.upsellTorOverVPNSubtitle)
        case .country:
            .init(
                text: Localizable.modalsNewUpsellCountrySubtitle,
                boldText: [Localizable.upsellCountryFeatureSubtitleBold]
            )
        case let .cantSkip(before, _, _):
            if before.timeIntervalSince(date.now) > 0 {
                .init(text: Localizable.upsellSpecificLocationSubtitle)
            } else {
                nil
            }
        case .moderateNAT:
            .init(
                text: Localizable.modalsNewUpsellModerateNatSubtitle,
                boldText: [Localizable.modalsUpsellModerateNatSubtitleBold]
            )
        case .hermes:
            .init(text: Localizable.hermesUpsellDescription)
        case .portForwarding:
            .init(text: Localizable.upsellPfSupportSubtitle)
        case .plutonium:
            .init(text: Localizable.plutoniumUpsellSubtitle)
        }
    }

    @MainActor @ViewBuilder
    func artImage() -> some View {
        switch self {
        case .subscription:
            Image(.welcomePlus)
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
        case let .country(countryCode):
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
        @Dependency(\.serverRepository) var serverRepository

        return switch self {
        case .netShield:
            [.blockAds, .protectFromMalware, .highSpeedNetshield]
        case .secureCore:
            [.routeSecureServers, .addLayer, .protectFromAttacks]
        case .allCountries:
            [.anyLocation, .higherSpeed, .geoblockedContent, .streaming]
        case .country:
            [
                .multipleCountries(serverRepository.countryCount()),
                .higherSpeed,
                .streaming,
                .multipleDevices(DomainConstants.maxDeviceCount),
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
        case .streaming, .p2pSupport, .portForwarding, .devices, .torOverVPN, .hermes, .plutonium:
            []
        case .subscription:
            []
        case .cantSkip:
            []
        }
    }
}
