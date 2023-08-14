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

    @ScaledMetric var featureIconSize: CGFloat = 16

    let connectionInfoBuilder: ConnectionInfoBuilder

    let intent: ConnectionSpec

    public init(intent: ConnectionSpec, vpnConnectionActual: VPNConnectionActual? = nil, withDivider: Bool) {
        self.intent = intent
        self.connectionInfoBuilder = .init(intent: intent,
                                           vpnConnectionActual: vpnConnectionActual)
        self.withDivider = withDivider
    }

    var withDivider: Bool

    var flag: some View {
        VStack(spacing: 0) {
            if withDivider {
                Spacer()
                    .frame(width: 20, height: 12)
            }
            FlagView(location: intent.location, flagSize: .defaultSize)
            if connectionInfoBuilder.hasTextFeatures {
                Spacer()
            }
            if withDivider {
                Spacer()
                    .frame(height: 12)
            }
        }
    }

    public var body: some View {
            HStack(spacing: 0) {
                flag
                Spacer()
                    .frame(width: 12)
                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 0) {
                            Text(connectionInfoBuilder.textHeader)
                                .styled()
#if canImport(Cocoa)
                                .themeFont(.body(emphasised: true))
#elseif canImport(UIKit)
                                .themeFont(.body1(.semibold))
#endif

                        if connectionInfoBuilder.hasTextFeatures {
                            connectionInfoBuilder
                                .textFeatures
                                .lineLimit(2)
                                .foregroundColor(.init(.border))
                        }
                    }
                    if withDivider {
                        VStack {
                            Spacer()
                            Divider()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: withDivider ? 64 : 42)
        }
}

struct ConnectionFlagView_Previews: PreviewProvider {

    static let cellHeight = 40.0
    static let cellWidth = 300.0
    static let spacing = 20.0

    static func sideBySide(intent: ConnectionSpec, actual: VPNConnectionActual) -> some View {
            HStack(alignment: .top, spacing: spacing) {
                ConnectionFlagInfoView(intent: intent, withDivider: true ).frame(width: cellWidth)
                Divider()
                ConnectionFlagInfoView(intent: intent, vpnConnectionActual: actual, withDivider: false).frame(width: cellWidth)
            }
        .frame(height: cellHeight)
    }

    static var previews: some View {
        VStack {
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: []),
                                   vpnConnectionActual: .mock(),
                                   withDivider: true)
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: []),
                                   vpnConnectionActual: .mock(),
                                   withDivider: false)
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: [.p2p, .tor]),
                                   vpnConnectionActual: .mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)),
                                   withDivider: true)
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .region(code: "US"),
                                                          features: [.p2p, .tor]),
                                   vpnConnectionActual: .mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)),
                                   withDivider: false)
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .fastest,
                                                          features: []),
                                   vpnConnectionActual: .mock(),
                                   withDivider: true)
            ConnectionFlagInfoView(intent: ConnectionSpec(location: .fastest,
                                                          features: [.p2p, .tor]),
                                   vpnConnectionActual: .mock(feature: ServerFeature(arrayLiteral: .p2p, .tor)),
                                   withDivider: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("single")

        VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .bottom, spacing: spacing) {
                Text("Not connected").frame(width: cellWidth)
                Divider()
                Text("Connected").frame(width: cellWidth)
            }.frame(height: cellHeight)
            Divider().frame(width: (cellWidth + spacing) * 2)

            sideBySide(
                intent: ConnectionSpec(location: .fastest, features: []),
                actual: .mock()
            )
            sideBySide(
                intent: ConnectionSpec(location: .region(code: "US"), features: []),
                actual: .mock()
            )
            sideBySide(
                intent: ConnectionSpec(location: .region(code: "US"), features: [.tor]),
                actual: .mock(feature: .tor)
            )
            sideBySide(
                intent: ConnectionSpec(location: .exact(.free, number: 1, subregion: nil, regionCode: "US"), features: []),
                actual: .mock(serverName: "FREE#1")
            )
            sideBySide(
                intent: ConnectionSpec(location: .exact(.paid, number: 1, subregion: nil, regionCode: "US"), features: [.p2p, .tor]),
                actual: .mock(feature: ServerFeature(arrayLiteral: .p2p, .tor))
            )
            sideBySide(
                intent: ConnectionSpec(location: .exact(.paid, number: 1, subregion: "AR", regionCode: "US"), features: []),
                actual: .mock()
            )
            sideBySide(
                intent: ConnectionSpec(location: .secureCore(.fastest), features: []),
                actual: .mock(country: "SE")
            )
            sideBySide(
                intent: ConnectionSpec(location: .secureCore(.hop(to: "JP", via: "CH")), features: []),
                actual: .mock()
            )
        }
        .previewLayout(.fixed(width: 700, height: 800))
        .previewDisplayName("sideBySide")
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
