//
//  Created on 05/03/2026 by Max Kupetskyi.
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

#if DEBUG
    import ComposableArchitecture
    import Domain

    public extension CountryFeature.State {
        static var previewNormal: Self {
            basePreviewState(countryCode: "US", showConnect: true, showFeatures: true)
        }

        static var previewUpgrade: Self {
            let state = basePreviewState(countryCode: "US", showConnect: true, showFeatures: true)
            state.$userTier = SharedReader(value: .freeTier)
            return state
        }

        static var previewSecureCore: Self {
            basePreviewState(countryCode: "CH", featureIntersection: [.secureCore], showConnect: true, showFeatures: true)
        }

        static var previewWithFlag: Self {
            basePreviewState(countryCode: "NL", showConnect: true, showFeatures: true, isSmartRouting: true, features: [.p2p])
        }

        static var previewNoConnectButton: Self {
            basePreviewState(countryCode: "US", showConnect: false, showFeatures: true, isSmartRouting: false, features: [])
        }

        static func basePreviewState(
            countryCode: String,
            featureIntersection: ServerFeature = [],
            showConnect: Bool,
            showFeatures: Bool,
            isSmartRouting: Bool = true,
            features: ServerFeature = [.tor, .p2p]
        ) -> Self {
            let state = CountryFeature.State(
                serverGroup: .init(
                    kind: .country(code: countryCode),
                    featureIntersection: featureIntersection,
                    featureUnion: features,
                    minTier: .freeTier,
                    maxTier: .paidTier,
                    serverCount: 1,
                    cityCount: 1,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: isSmartRouting,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
                serverType: .standard,
                showCountryConnectButton: showConnect,
                showFeatureIcons: showFeatures,
                serversFilter: .default
            )
            state.$userTier = SharedReader(value: .paidTier)
            return state
        }
    }
#endif
