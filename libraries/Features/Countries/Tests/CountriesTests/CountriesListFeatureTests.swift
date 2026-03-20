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
    import ComposableArchitecture
    @testable import Countries_macOS
    import CountriesShared
    import PaymentsShared
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
    }
#endif
