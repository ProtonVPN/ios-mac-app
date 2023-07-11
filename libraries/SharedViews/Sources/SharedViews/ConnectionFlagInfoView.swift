//
//  Created on 2023-06-30.
//
//  Copyright (c) 2023 Proton AG
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

import SwiftUI
import VPNAppCore
import Theme
import Dependencies
import Strings

public struct ConnectionFlagInfoView: View {

    public let intent: ConnectionSpec
    public let vpnConnectionActual: VPNConnectionActual?

    public var location: ConnectionSpec.Location { intent.location }
    @Dependency(\.locale) private var locale

    @ScaledMetric(relativeTo: .body) var topLineHeight: CGFloat = 16
    @ScaledMetric var featureIconSize: CGFloat = 16

    public init(intent: ConnectionSpec, vpnConnectionActual: VPNConnectionActual? = nil) {
        self.intent = intent
        self.vpnConnectionActual = vpnConnectionActual
    }

    @ViewBuilder
    var flag: some View {
        switch location {
        case .fastest:
            SimpleFlagView(regionCode: "Fastest", flagSize: .defaultSize)
        case .region(let code):
            SimpleFlagView(regionCode: code, flagSize: .defaultSize)
        case .exact(_, _, _, let code):
            SimpleFlagView(regionCode: code, flagSize: .defaultSize)
        case .secureCore(let secureCoreSpec):
            switch secureCoreSpec {
            case .fastest:
                SecureCoreFlagView(regionCode: "Fastest", viaRegionCode: nil, flagSize: .defaultSize)
            case let .fastestHop(code):
                SecureCoreFlagView(regionCode: code, viaRegionCode: nil, flagSize: .defaultSize)
            case let .hop(code, via):
                SecureCoreFlagView(regionCode: code, viaRegionCode: via, flagSize: .defaultSize)
            }
        }
    }

    var textHeader: String {
        return location.text(locale: locale)
    }

    var textSubHeader: String? {
        if let vpnConnectionActual {
            switch location {
            case .fastest:
                return LocalizationUtility.default.countryName(forCode: vpnConnectionActual.country)
            case .region:
                return nil
            case .exact:
                return vpnConnectionActual.serverName
            case .secureCore(let secureCoreSpec):
                switch secureCoreSpec {
                case .fastest:
                    return LocalizationUtility.default.countryName(forCode: vpnConnectionActual.country)
                case .fastestHop:
                    return nil
                case .hop:
                    return Localizable.secureCoreViaCountry(LocalizationUtility.default.countryName(forCode: vpnConnectionActual.country) ?? "")
                }
            }
        }
        return location.subtext(locale: locale)
    }

    @ViewBuilder
    var textFeatures: some View {
        HStack(spacing: 8) {
            if showFeatureBullet {
                Text("• ")
            }
            if showFeatureP2P {
                Asset.icArrowRightArrowLeft.swiftUIImage
                    .resizable()
                    .frame(width: featureIconSize, height: featureIconSize)
                Text("P2P").styled(.weak)
            } else
            if showFeatureTor {
                Asset.icBrandTor.swiftUIImage
                    .resizable()
                    .frame(width: featureIconSize, height: featureIconSize)
                Text("Tor").styled(.weak)
            }
        }
    }

    /// In case of not an actual connection, show feature only if present in both intent and actual connection.
    /// In case of intent, check only if feature was intended.
    private var showFeatureP2P: Bool {
        if intent.features.contains(.p2p) {
            if let vpnConnectionActual {
                return vpnConnectionActual.feature.contains(.p2p)
            } else {
                return true
            }
        }
        return false
    }

    /// In case of not an actual connection, show feature only if present in both intent and actual connection.
    /// In case of intent, check only if feature was intended.
    private var showFeatureTor: Bool {
        if intent.features.contains(.tor) {
            if let vpnConnectionActual {
                return vpnConnectionActual.feature.contains(.tor)
            } else {
                return true
            }
        }
        return false
    }

    /// Bullet is shown between any sub-header text and feature view
    private var showFeatureBullet: Bool {
        return textSubHeader != nil && (showFeatureP2P || showFeatureTor)
    }

    public var body: some View {
        HStack(alignment: .top) {
            flag.padding(0)

            VStack(alignment: .leading) {
                Text(textHeader)
                    .styled()
#if canImport(Cocoa)
                    .themeFont(.body())
#elseif canImport(UIKit)
                    .themeFont(.body1(.semibold))
#endif
                    .frame(minHeight: topLineHeight)

                HStack(spacing: 8) {
                    if let subtext = textSubHeader {
                        Text(subtext)
                            .styled(.weak)
                    }

                    textFeatures
                }
#if canImport(Cocoa)
                            .font(.body())
#elseif canImport(UIKit)
                            .font(.caption())
#endif
            }.padding(.leading, 8)
        }
    }
}

struct ConnectionFlagView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 10) {

            VStack(alignment: .leading, spacing: 10) {
                Text("Not connected:")
                Group {
                    ConnectionFlagInfoView(intent: ConnectionSpec(location: .fastest, features: []) )
                    Divider()
                    ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"), features: []))
                    Divider()
                    ConnectionFlagInfoView(intent: ConnectionSpec(location: .exact(.free, number: 1, subregion: nil, regionCode: "US"), features: []))
                    Divider()
                    ConnectionFlagInfoView(intent: ConnectionSpec(location: .exact(.paid, number: 1, subregion: nil, regionCode: "US"), features: [.p2p]))
                    Divider()
                }
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .exact(.paid, number: 1, subregion: "AR", regionCode: "US"), features: []))
                Divider()
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .secureCore(.fastest), features: []))
                Divider()
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .secureCore(.fastestHop(to: "SE")), features: []))
                Divider()
                ConnectionFlagInfoView(intent: ConnectionSpec(location: .secureCore(.hop(to: "JP", via: "CH")), features: []))

            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Connected:")
                Group {
                    ConnectionFlagInfoView(
                        intent: ConnectionSpec(location: .fastest, features: []),
                        vpnConnectionActual: .mock()
                        )
                    Divider()
                    ConnectionFlagInfoView(
                        intent: ConnectionSpec(location: .region(code: "US"), features: []),
                        vpnConnectionActual: .mock()
                    )
                    Divider()
                    ConnectionFlagInfoView(
                        intent: ConnectionSpec(location: .region(code: "US"), features: [.tor]),
                        vpnConnectionActual: .mock(feature: .tor)
                    )
                    Divider()
                    ConnectionFlagInfoView(
                        intent: ConnectionSpec(location: .exact(.free, number: 1, subregion: nil, regionCode: "US"), features: []),
                        vpnConnectionActual: .mock()
                    )
                    Divider()
                    ConnectionFlagInfoView(
                        intent: ConnectionSpec(location: .exact(.paid, number: 1, subregion: nil, regionCode: "US"), features: [.p2p]),
                        vpnConnectionActual: .mock(feature: .p2p)
                    )
                    Divider()
                }
                ConnectionFlagInfoView(
                    intent: ConnectionSpec(location: .exact(.paid, number: 1, subregion: "NY", regionCode: "US"), features: []),
                    vpnConnectionActual: .mock()
                )
                Divider()
                ConnectionFlagInfoView(
                    intent: ConnectionSpec(location: .secureCore(.fastest), features: []),
                    vpnConnectionActual: .mock()
                )
                Divider()
                ConnectionFlagInfoView(
                    intent: ConnectionSpec(location: .secureCore(.fastestHop(to: "SE")), features: []),
                    vpnConnectionActual: .mock(country: "SE")
                )
                Divider()
                ConnectionFlagInfoView(
                    intent: ConnectionSpec(location: .secureCore(.hop(to: "JP", via: "CH")), features: []),
                    vpnConnectionActual: .mock()
                )

            }
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

// MARK: - Model extensions

public extension ConnectionSpec.Location {

    private func regionName(locale: Locale, code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    func accessibilityText(locale: Locale) -> String {
        switch self {
        case .fastest:
            return "The fastest country available"
        case .secureCore(.fastest):
            return "The fastest secure core country available"
        default:
            // todo: .exact and .region should specify number and ideally features as well
            return text(locale: locale)
        }
    }

    func text(locale: Locale) -> String {
        switch self {
        case .fastest,
                .secureCore(.fastest):
            return "Fastest"
        case .region(let code),
                .exact(_, _, _, let code),
                .secureCore(.fastestHop(let code)),
                .secureCore(.hop(let code, _)):
            return regionName(locale: locale, code: code)
        }
    }

    func subtext(locale: Locale) -> String? {
        switch self {
        case .fastest, .region, .secureCore(.fastest), .secureCore(.fastestHop):
            return nil
        case let .exact(server, number, subregion, _):
            if server == .free {
                return "FREE#\(number)"
            } else if let subregion {
                return "\(subregion) #\(number)"
            } else {
                return nil
            }
        case .secureCore(.hop(_, let via)):
            return "via \(regionName(locale: locale, code: via))"
        }
    }
}
