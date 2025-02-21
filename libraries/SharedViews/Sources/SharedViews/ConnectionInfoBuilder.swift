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

import ComposableArchitecture
import Dependencies

import Ergonomics
import Domain
import Ergonomics
import Strings
import Localization
import Theme
import VPNAppCore

// VPNAPPL-2542: Separate out view (e.g. Locale) and business (what elements to display) logic into separate
// dependencies used in the appropriate layers. Remove usages of business logic dependencies from view layer.
public struct ConnectionInfoBuilder {
    let withServerNumber: Bool
    public let intent: ConnectionSpec
    public let server: Server?
    public var location: ConnectionSpec.Location { intent.location }
    @Dependency(\.locale) private var locale
    @SharedReader(.userTier) private var userTier: Int

    public init(intent: ConnectionSpec, server: Server?, withServerNumber: Bool) {
        self.intent = intent
        self.server = server
        self.withServerNumber = withServerNumber
    }

    private var subheaderString: String? {
        guard let server else {
            return location.subtext(locale: locale)
        }
        switch location {
        case .fastest:
            let countryName = LocalizationUtility.default.countryName(forCode: server.logical.exitCountryCode) ?? server.logical.exitCountryCode
            if withServerNumber, let number = server.logical.serverNameComponents.sequence {
                return countryName + " #\(number)"
            }
            return countryName
        case .random:
            if withServerNumber, let sequence = server.logical.serverNameComponents.sequence {
                return "#\(sequence)"
            }
            return server.logical.name
        case .region:
            return nil
        case .exact:
            return server.logical.name
        case .secureCore(let secureCoreSpec):
            switch secureCoreSpec {
            case .fastest, .random:
                return LocalizationUtility.default.countryName(forCode: server.logical.exitCountryCode)
            case .fastestHop:
                guard case let .secureCore(entryCode) = server.logical.kind else {
                    return nil
                }
                return Localizable.secureCoreViaCountry(LocalizationUtility.default.countryName(forCode: entryCode) ?? "")
            case .hop(_, let via):
                return Localizable.secureCoreViaCountry(LocalizationUtility.default.countryName(forCode: via) ?? "")
            }
        }
    }

    public var subheader: LocationFeatureSubheaderModel {
        if let subheaderString {
            let model = LocationFeatureSubheaderModel.TextSubheaderModel(
                location: subheaderString,
                showTor: shouldShow(feature: .tor),
                showP2P: shouldShow(feature: .p2p)
            )
            return .textual(model)
        } else if case .fastest = location, userTier.isFreeTier && server == nil {
            return .freeServerSelectionDisclaimer(additionalFreeCountryCount: Constants.additionalFreeCountryCount)
        } else {
            return .none
        }
    }

    /// In case of not an actual connection, show feature only if present in both intent and actual connection.
    /// In case of intent, check only if feature was intended.
    private func shouldShow(feature: ConnectionSpec.Feature) -> Bool {
        guard intent.features.contains(feature) else { return false }
        guard let currentlyConnectedServer = server else { return true }
        return currentlyConnectedServer.features.contains(feature)
    }

    private var showFeatureP2P: Bool {
        shouldShow(feature: .p2p)
    }

    private var showFeatureTor: Bool {
        shouldShow(feature: .tor)
    }

    public var textHeader: String {
        if let locationHeaderText = location.headerText(locale: locale) {
            return locationHeaderText
        } else if let server {
            let countryCode = server.logical.exitCountryCode
            return locale.localizedString(forRegionCode: countryCode) ?? countryCode
        } else {
            return location.text(locale: locale)
        }
    }

    public var resolvedLocation: ConnectionSpec.Location {
        guard case .random = location else {
            return location
        }
        guard let server else {
            return location
        }
        return ConnectionSpec.Location.region(code: server.logical.exitCountryCode)
    }
}
