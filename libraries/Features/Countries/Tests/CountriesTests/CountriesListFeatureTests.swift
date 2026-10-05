//
//  Created on 31/03/2026 by Max Kupetskyi.
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

#if os(macOS)
    import CommonNetworking
    import ComposableArchitecture
    @testable import Countries_macOS
    import CountriesShared
    import Domain
    import Foundation
    import LegacyCommon
    import PaymentsShared
    import Persistence
    import PersistenceTestSupport
    import Testing

    @Suite("Countries List Feature Tests mac")
    @MainActor
    struct CountriesListFeatureTests {
        @Test("upsell banner tap presents all countries upsell")
        func upsellBannerTapPresentsAllCountriesUpsell() async {
            let store = TestStore(initialState: CountriesListFeature.State()) {
                CountriesListFeature()
            } withDependencies: {
                $0.serverRepository = .notEmpty()
            }

            await store.send(.upsellBannerTapped) {
                $0.destination = .allCountriesUpsell(
                    .init(modalType: .allCountries(numberOfServers: 1, numberOfCountries: 1))
                )
            }
        }

        @Test("free connections upgrade tap presents all countries upsell")
        func freeConnectionsUpgradeTapPresentsAllCountriesUpsell() async {
            var state = CountriesListFeature.State()
            state.destination = .freeConnectionsInfo(.init(countries: []))

            let store = TestStore(initialState: state) {
                CountriesListFeature()
            } withDependencies: {
                $0.serverRepository = .notEmpty()
            }

            await store.send(.destination(.presented(.freeConnectionsInfo(.upgradeTapped)))) {
                $0.destination = .allCountriesUpsell(
                    .init(modalType: .allCountries(numberOfServers: 1, numberOfCountries: 1))
                )
            }
        }

        @Test("dismiss clears all countries upsell destination")
        func dismissClearsAllCountriesUpsellDestination() async {
            var state = CountriesListFeature.State()
            state.destination = .allCountriesUpsell(
                .init(modalType: .allCountries(numberOfServers: 1, numberOfCountries: 1))
            )

            let store = TestStore(initialState: state) {
                CountriesListFeature()
            }

            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
        }

        @Test("search text ignores duplicate values")
        func searchTextIgnoresDuplicateValues() async {
            var state = CountriesListFeature.State()
            state.searchText = "us"

            let store = TestStore(initialState: state) {
                CountriesListFeature()
            }

            await store.send(.searchText("us"))
        }
    }

    /// These tests post app-wide notifications, so they run one at a time to keep each store from seeing the others.
    @Suite("Countries List Feature reload tests mac", .serialized)
    @MainActor
    struct CountriesListFeatureReloadTests {
        @Test("choosing Smart queries the list for the protocols Smart uses")
        func choosingSmartQueriesTheListAgain() async {
            let propertiesManager = PropertiesManagerMock()
            propertiesManager.vpnProtocol = .ike
            let queriedSupport = LockIsolated<[ProtocolSupport]>([])
            var repository = ServerRepository.empty()
            repository.groups = { filters, _, _ in
                for case let .supports(protocol: support) in filters {
                    queriedSupport.withValue { $0.append(support) }
                }
                return []
            }

            let store = TestStore(initialState: CountriesListFeature.State()) {
                CountriesListFeature()
            } withDependencies: {
                $0.propertiesManager = propertiesManager
                $0.serverRepository = repository
            }

            // The list starts out loading, so the first query leaves the state as it is.
            await store.send(.startObserving)
            await store.receive(\.getGroups)
            await store.receive(\.loadOfferBanner)
            await store.receive(\.loadingFinished) { $0.listState = .loaded }

            propertiesManager.smartProtocol = true
            await store.receive(\.getGroups) { $0.listState = .loading }
            await store.receive(\.loadOfferBanner)
            await store.receive(\.loadingFinished) { $0.listState = .loaded }

            let ikeSupport = VpnProtocol.ike.protocolSupport
            let smartSupport = ProtocolSupport(vpnProtocols: SmartProtocolConfig().supportedProtocols)
            // One country query and one gateway query per load.
            #expect(queriedSupport.value == [ikeSupport, ikeSupport, smartSupport, smartSupport])
            await store.skipInFlightEffects()
        }

        @Test("a server list update queries the list again and keeps the rows on screen")
        func serverListUpdateQueriesTheListAgain() async {
            let store = TestStore(initialState: CountriesListFeature.State()) {
                CountriesListFeature()
            } withDependencies: {
                $0.propertiesManager = PropertiesManagerMock()
                $0.serverRepository = .empty()
            }

            // The list starts out loading, so the first query leaves the state as it is.
            await store.send(.startObserving)
            await store.receive(\.getGroups)
            await store.receive(\.loadOfferBanner)
            await store.receive(\.loadingFinished) { $0.listState = .loaded }

            // The list state stays loaded for the whole reload.
            NotificationCenter.default.post(name: ServerListUpdateNotification.name, object: nil)
            await store.receive(\.reloadGroups)
            await store.receive(\.loadOfferBanner)
            await store.receive(\.loadingFinished)

            await store.skipInFlightEffects()
        }
    }
#endif
