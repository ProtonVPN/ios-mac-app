//
//  Created on 16/03/2026 by Max Kupetskyi.
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

#if os(iOS)
    import Clocks
    import ComposableArchitecture
    @testable import Countries_iOS
    @testable import CountriesShared
    import Dependencies
    import Domain
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import VPNAppCore
    import VPNShared

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct CountriesViewSnapshotTests {
        @Test("Countries view - Standard mode with mixed countries")
        func countriesViewStandardMode() {
            @Shared(.secureCoreToggle) var secureCoreToggle = false
            @Shared(.userTier) var userTier: Int? = .paidTier
            @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

            withDependencies {
                $0.continuousClock = TestClock()
            } operation: {
                let view = CountriesView(store: Store(
                    initialState: .init(sections: standardSections)
                ) {
                    CountriesFeature()
                })
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
            }
        }

        @Test("Countries view - Secure Core mode")
        func countriesViewSecureCoreMode() {
            @Shared(.secureCoreToggle) var secureCoreToggle = true
            @Shared(.userTier) var userTier: Int? = .paidTier
            @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

            withDependencies {
                $0.continuousClock = TestClock()
            } operation: {
                let view = CountriesView(store: Store(
                    initialState: .init(sections: secureCoreSections)
                ) {
                    CountriesFeature()
                })
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
            }
        }

        @Test("Countries view - With banners")
        func countriesViewWithBanners() {
            @Shared(.secureCoreToggle) var secureCoreToggle = false
            @Shared(.userTier) var userTier: Int? = .freeTier
            @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

            withDependencies {
                $0.continuousClock = TestClock()
                $0.date.now = fixedCurrentDate
                $0.locale = Locale(identifier: "en_US_POSIX")
                $0.timeZone = TimeZone(identifier: "UTC")!
            } operation: {
                let view = CountriesView(store: Store(
                    initialState: .init(sections: sectionsWithBanners)
                ) {
                    CountriesFeature()
                })
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 900)))
            }
        }

        @Test("Countries view - Free user view")
        func countriesViewFreeUser() {
            @Shared(.secureCoreToggle) var secureCoreToggle = false
            @Shared(.userTier) var userTier: Int? = .freeTier
            @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

            withDependencies {
                $0.continuousClock = TestClock()
            } operation: {
                let view = CountriesView(store: Store(
                    initialState: .init(sections: freeUserSections)
                ) {
                    CountriesFeature()
                })
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
            }
        }

        private var standardSections: IdentifiedArrayOf<CountrySectionFeature.State> {
            let fastest = RowFeature.State.profile(
                .init(serverOffering: .fastest(nil), extraMargin: true)
            )
            let countries: [RowFeature.State] = [
                .country(countryState(code: "US", secureCore: false)),
                .country(countryState(code: "NL", secureCore: false)),
                .country(countryState(code: "JP", secureCore: false)),
            ]

            return [
                .init(
                    id: .allCountries,
                    type: .countries,
                    title: "All locations (4)",
                    rows: IdentifiedArray(uniqueElements: [fastest] + countries),
                    hasInfoButton: false,
                    serversFilter: .default
                ),
            ]
        }

        private var secureCoreSections: IdentifiedArrayOf<CountrySectionFeature.State> {
            let countries: [RowFeature.State] = [
                .country(countryState(code: "CH", secureCore: true)),
                .country(countryState(code: "IS", secureCore: true)),
                .country(countryState(code: "SE", secureCore: true)),
            ]

            return [
                .init(
                    id: .allCountries,
                    type: .countries,
                    title: "Secure Core locations (3)",
                    rows: IdentifiedArray(uniqueElements: countries),
                    hasInfoButton: false,
                    serversFilter: .default
                ),
            ]
        }

        private var freeUserSections: IdentifiedArrayOf<CountrySectionFeature.State> {
            let fastest = RowFeature.State.profile(
                .init(serverOffering: .fastest(nil), extraMargin: false)
            )
            let countries: [RowFeature.State] = [
                .country(countryState(code: "US", secureCore: false)),
                .country(countryState(code: "NL", secureCore: false)),
                .country(countryState(code: "JP", secureCore: false)),
            ]

            return [
                .init(
                    id: .freeProfiles,
                    type: .profiles,
                    title: "Free connections (1)",
                    rows: [fastest],
                    hasInfoButton: true,
                    serversFilter: .none
                ),
                .init(
                    id: .paidCountries,
                    type: .countries,
                    title: "Plus locations (3)",
                    rows: IdentifiedArray(uniqueElements: countries),
                    hasInfoButton: false,
                    serversFilter: .default
                ),
            ]
        }

        private var sectionsWithBanners: IdentifiedArrayOf<CountrySectionFeature.State> {
            let fastest = RowFeature.State.profile(
                .init(serverOffering: .fastest(nil), extraMargin: false)
            )
            let rows: [RowFeature.State] = [
                .banner(.init(bannerType: .upsell)),
                .country(countryState(code: "US", secureCore: false)),
                .country(countryState(code: "NL", secureCore: false)),
            ]

            return [
                .init(
                    id: .freeProfiles,
                    type: .profiles,
                    title: "Free connections (1)",
                    rows: [fastest],
                    hasInfoButton: true,
                    serversFilter: .none
                ),
                .init(
                    id: .paidCountries,
                    type: .countries,
                    title: "Plus locations (2)",
                    rows: IdentifiedArray(uniqueElements: rows),
                    hasInfoButton: false,
                    serversFilter: .default
                ),
            ]
        }

        private func countryState(code: String, secureCore: Bool) -> CountryFeature.State {
            .init(
                serverGroup: .init(
                    kind: .country(code: code),
                    featureIntersection: secureCore ? [.secureCore] : [],
                    featureUnion: [.p2p, .tor],
                    minTier: .paidTier,
                    maxTier: .paidTier,
                    serverCount: 1,
                    cityCount: 1,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: true,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
                serverType: secureCore ? .secureCore : .standard,
                showCountryConnectButton: true,
                showFeatureIcons: true,
                serversFilter: .default
            )
        }

        private var fixedCurrentDate: Date {
            Date(timeIntervalSince1970: 1_736_942_400)
        }
    }

    extension CountriesViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Countries/Tests/CountriesTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
