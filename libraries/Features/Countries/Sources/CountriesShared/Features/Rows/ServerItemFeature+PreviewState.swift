//
//  Created on 10/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

#if DEBUG
    import ComposableArchitecture
    import Domain

    public extension ServerItemFeature.State {
        static var previewNormal: Self {
            basePreviewState(
                id: "us-ny-123",
                name: "US-NY#123",
                city: "New York",
                translatedCity: nil,
                entryCountryCode: "US",
                exitCountryCode: "US",
                tier: .paidTier,
                load: 56,
                feature: [.p2p, .tor],
                serverType: .standard,
                userTier: .paidTier,
                status: 1
            )
        }

        static var previewSecureCore: Self {
            basePreviewState(
                id: "ch-us-5",
                name: "CH-US#5",
                city: "New York",
                translatedCity: nil,
                entryCountryCode: "",
                exitCountryCode: "US",
                tier: .paidTier,
                load: 56,
                feature: [.secureCore],
                serverType: .secureCore,
                userTier: .paidTier,
                status: 1
            )
        }

        static var previewSecureCoreWithFlags: Self {
            basePreviewState(
                id: "ch-us-7",
                name: "CH-US#7",
                city: "New York",
                translatedCity: nil,
                entryCountryCode: "CH",
                exitCountryCode: "US",
                tier: .paidTier,
                load: 56,
                feature: [.secureCore],
                serverType: .secureCore,
                userTier: .paidTier,
                status: 1
            )
        }

        static var previewUnderMaintenance: Self {
            basePreviewState(
                id: "uk-lon-45",
                name: "UK-LON#45",
                city: "London",
                translatedCity: nil,
                entryCountryCode: "GB",
                exitCountryCode: "GB",
                tier: .paidTier,
                load: 56,
                feature: [],
                serverType: .standard,
                userTier: .paidTier,
                status: 0
            )
        }

        static var previewUpgrade: Self {
            basePreviewState(
                id: "nl-ams-78",
                name: "NL-AMS#78",
                city: "Amsterdam",
                translatedCity: nil,
                entryCountryCode: "NL",
                exitCountryCode: "NL",
                tier: .paidTier,
                load: 56,
                feature: [.p2p, .tor],
                serverType: .standard,
                userTier: .freeTier,
                status: 1
            )
        }

        static var previewStreaming: Self {
            basePreviewState(
                id: "us-ca-201",
                name: "US-CA#201",
                city: "Los Angeles",
                translatedCity: nil,
                entryCountryCode: "US",
                exitCountryCode: "US",
                tier: .paidTier,
                load: 75,
                feature: [.streaming],
                serverType: .standard,
                userTier: .paidTier,
                status: 1
            )
        }

        static var previewHighLoad: Self {
            basePreviewState(
                id: "fr-par-12",
                name: "FR-PAR#12",
                city: "Paris",
                translatedCity: nil,
                entryCountryCode: "FR",
                exitCountryCode: "FR",
                tier: .paidTier,
                load: 91,
                feature: [],
                serverType: .standard,
                userTier: .paidTier,
                status: 1,
                hostCountry: "DE"
            )
        }

        static var previewLowLoad: Self {
            basePreviewState(
                id: "jp-tky-56",
                name: "JP-TKY#56",
                city: "Tokyo",
                translatedCity: nil,
                entryCountryCode: "JP",
                exitCountryCode: "JP",
                tier: .paidTier,
                load: 12,
                feature: [.tor],
                serverType: .standard,
                userTier: .paidTier,
                status: 1
            )
        }

        static var previewTranslatedCity: Self {
            basePreviewState(
                id: "es-bcn-89",
                name: "ES-BCN#89",
                city: "Barcelona",
                translatedCity: "Барселона",
                entryCountryCode: "ES",
                exitCountryCode: "ES",
                tier: .paidTier,
                load: 56,
                feature: [],
                serverType: .standard,
                userTier: .paidTier,
                status: 1,
                hostCountry: "PT"
            )
        }

        private static func basePreviewState(
            id: String,
            name: String,
            city: String,
            translatedCity: String?,
            entryCountryCode: String,
            exitCountryCode: String,
            tier: Int,
            load: Int,
            feature: ServerFeature,
            serverType: ServerType,
            userTier: Int,
            status: Int,
            hostCountry: String? = nil
        ) -> Self {
            var state = ServerItemFeature.State(
                serverInfo: .init(
                    logical: .init(
                        id: id,
                        name: name,
                        domain: "\(id).protonvpn.net",
                        load: load,
                        entryCountryCode: entryCountryCode,
                        exitCountryCode: exitCountryCode,
                        tier: tier,
                        score: 0,
                        status: status,
                        feature: feature,
                        city: city,
                        state: nil,
                        hostCountry: hostCountry,
                        translatedCity: translatedCity,
                        latitude: 0,
                        longitude: 0,
                        gatewayName: nil
                    ),
                    protocolSupport: .all
                ),
                serverType: serverType
            )
            state.$userTier = .constant(userTier)
            return state
        }
    }
#endif
