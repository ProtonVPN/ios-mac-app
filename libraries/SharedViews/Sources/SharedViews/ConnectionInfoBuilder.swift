//
//  Created on 14/07/2023.
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

import Dependencies

import Domain
import Strings
import Localization
import Theme
import VPNAppCore

public struct ConnectionInfoBuilder {

    public let intent: ConnectionSpec
    public let vpnConnectionActual: VPNConnectionActual?
    public var location: ConnectionSpec.Location { intent.location }
    @Dependency(\.locale) private var locale

    public init(intent: ConnectionSpec, vpnConnectionActual: VPNConnectionActual?) {
        self.intent = intent
        self.vpnConnectionActual = vpnConnectionActual
    }

    public var textSubHeader: String? {
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

    /// In case of not an actual connection, show feature only if present in both intent and actual connection.
    /// In case of intent, check only if feature was intended.
    private var showFeatureP2P: Bool {
        if intent.features.contains(.p2p) {
            if let vpnConnectionActual {
                return vpnConnectionActual.feature.contains(ServerFeature.p2p)
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
                return vpnConnectionActual.feature.contains(ServerFeature.tor)
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

    var hasTextFeatures: Bool {
        textSubHeader != nil || showFeatureP2P || showFeatureTor
    }

    @ViewBuilder
    public var textFeatures: some View {
        // Format looks weird, but it lets us merge several Texts and images
        // into one, so whole behaves like a text: it can wrap lines, resize
        // icons inside, etc. For this to work, images have to be either
        // created with `Image(systemName:)` or be imported as a `Symbol Image`.
        (
            Text("") // In case nothing is returned in next lines, we still have at least empty text
            + (textSubHeader != nil
               ? Text("\(textSubHeader!)")
               : Text("")
              )
            + (showFeatureP2P
               ? (showFeatureBullet ? Text(" • ") : Text(""))
               + Text(Image(systemName: "arrow.left.arrow.right"))
               + Text(" \(Localizable.connectionDetailsFeatureTitleP2p)")
               : Text("")
              )
            + (showFeatureTor
               ? (showFeatureBullet || showFeatureP2P ? Text(" • ") : Text(""))
               + Text("\(Asset.icsBrandTor.swiftUIImage)")
               + Text(" \(Localizable.connectionDetailsFeatureTitleTor)")
               : Text("")
              )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundColor(Color(.text, .weak))
#if canImport(Cocoa)
        .font(.body())
#elseif canImport(UIKit)
        .font(.caption())
#endif
    }

    public var textHeader: String {
        return location.text(locale: locale)
    }
}
