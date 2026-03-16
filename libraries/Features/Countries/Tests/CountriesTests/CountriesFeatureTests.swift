//
//  Created on 22/01/2026 by Max Kupetskyi.
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

import ComposableArchitecture
@testable import CountriesShared
import Domain
import LegacyCommon
import Localization
import PaymentsShared
import PersistenceTestSupport
import Strings
import Testing
import VPNAppCore

@Suite("Countries Feature Tests")
@MainActor
struct CountriesFeatureTests {
    // MARK: - Secure Core Toggle Tests

    @Test("Secure core toggle works for paid user when disconnected")
    func secureCoreToggleWhenDisconnectedAndPaidUser() async {
        @Shared(.secureCoreToggle) var isSecureCore = false
        @Shared(.userTier) var userTier: Int? = 2
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested)
        await store.receive(\.applySecureCoreToggle)
    }

    @Test("Secure core toggle shows upsell for free user")
    func secureCoreToggleShowsUpsellForFreeUser() async {
        @Shared(.secureCoreToggle) var isSecureCore = false
        @Shared(.userTier) var userTier: Int? = 0
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.destination = .payments(.init(upsellModalType: .secureCore))
        }
    }

    @Test("All countries upsell action presents payments destination")
    func allCountriesUpsellPresentsPayments() async {
        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
        }

        await store.send(.presentAllCountriesUpsell) {
            $0.destination = .payments(
                .init(upsellModalType: .allCountries(numberOfServers: 1, numberOfCountries: 1))
            )
        }
    }

    @Test("Country upsell action presents country-specific payments modal")
    func countryUpsellPresentsCountryModal() async {
        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
        }

        await store.send(.presentCountryUpsell("NL")) {
            $0.destination = .payments(
                .init(
                    upsellModalType: .country(
                        countryCode: "NL",
                        numberOfDevices: DomainConstants.maxDeviceCount,
                        numberOfCountries: 1
                    )
                )
            )
        }
    }

    @Test("Secure core toggle shows discourage view when enabled")
    func secureCoreToggleShowsDiscourageViewWhenEnabled() async {
        @Shared(.secureCoreToggle) var isSecureCore = false
        @Shared(.userTier) var userTier: Int? = 2
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.discourageSecureCore = true

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        } withDependencies: {
            $0.propertiesManager = propertiesManager
        }

        await store.send(.secureCoreToggleRequested) {
            $0.destination = .discourageSecureCoreView(.init())
        }
    }

    @Test("Secure core toggle shows disconnect alert when connected")
    func secureCoreToggleShowsDisconnectAlertWhenConnected() async {
        @Shared(.secureCoreToggle) var isSecureCore = false
        @Shared(.userTier) var userTier: Int? = 2
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .connected(.defaultFastest, nil)

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.alert = AlertState(
                title: { TextState(Localizable.warning) },
                actions: {
                    ButtonState(
                        action: .send(.disconnectAndToggle),
                        label: { TextState(Localizable.continue) }
                    )
                    ButtonState(
                        role: .cancel,
                        action: .send(.cancel),
                        label: { TextState(Localizable.cancel) }
                    )
                },
                message: { TextState(Localizable.viewToggleWillCauseDisconnect) }
            )
        }
    }

    @Test("Turning off secure core when connected shows alert")
    func turningOffSecureCoreWhenConnectedShowsAlert() async {
        @Shared(.secureCoreToggle) var isSecureCore = true
        @Shared(.userTier) var userTier: Int? = 2
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .connected(.defaultFastest, nil)

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.alert = AlertState(
                title: { TextState(Localizable.warning) },
                actions: {
                    ButtonState(
                        action: .send(.disconnectAndToggle),
                        label: { TextState(Localizable.continue) }
                    )
                    ButtonState(
                        role: .cancel,
                        action: .send(.cancel),
                        label: { TextState(Localizable.cancel) }
                    )
                },
                message: { TextState(Localizable.viewToggleWillCauseDisconnect) }
            )
        }
    }

    @Test("Turning off secure core when disconnected applies toggle")
    func turningOffSecureCoreWhenDisconnected() async {
        @Shared(.secureCoreToggle) var isSecureCore = true
        @Shared(.userTier) var userTier: Int? = 2
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested)
        await store.receive(\.applySecureCoreToggle)
    }

    // MARK: - Alert Action Tests

    @Test("Alert cancel dismisses alert")
    func alertCancelDismissesAlert() async {
        var state = CountriesFeature.State(sections: [])
        state.alert = AlertState(title: { TextState("Test") })

        let store = TestStore(initialState: state) {
            CountriesFeature()
        }

        await store.send(.alert(.presented(.cancel))) {
            $0.alert = nil
        }
    }

    @Test("Alert disconnect and toggle when connected")
    func alertDisconnectAndToggleWhenConnected() async {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .connected(.defaultFastest, nil)

        var state = CountriesFeature.State(sections: [])
        state.alert = AlertState(title: { TextState("Test") })

        let store = TestStore(initialState: state) {
            CountriesFeature()
        }

        await store.send(.alert(.presented(.disconnectAndToggle))) {
            $0.alert = nil
        }
        await store.receive(\.applySecureCoreToggle)
    }

    // MARK: - Navigation Tests

    @Test("Show features info presents destination")
    func showFeaturesInfo() async {
        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.showFeaturesInfo) {
            $0.destination = .serversFeaturesInfo(ServersFeaturesInformationFeature.State.servicesInfo)
        }
    }

    @Test("Show servers streaming features info presents destination")
    func showServersStreamingFeaturesInfo() async {
        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.showServersStreamingFeaturesInfo) {
            $0.destination = .serversStreamingFeaturesInfo(
                ServersStreamingFeaturesFeature.State(
                    countryName: "Country",
                    streamingServices: IdentifiedArrayOf<StreamingServiceItem.State>()
                )
            )
        }
    }

    @Test("Free connections info action presents free servers info destination")
    func presentFreeConnectionsInfoPresentsDestination() async {
        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.presentFreeConnectionsInfo) {
            $0.destination = .freeConnectionsView(.init(countries: []))
        }
    }

    @Test("Free profiles info button routes to free connections info")
    func freeProfilesInfoButtonRoutesToFreeConnectionsInfo() async {
        let sections: IdentifiedArrayOf<CountrySectionFeature.State> = [
            .init(
                id: .freeProfiles,
                type: .profiles,
                title: Localizable.connectionsFreeWithCount(1),
                rows: [],
                hasInfoButton: true,
                serversFilter: .none
            ),
        ]
        let store = TestStore(initialState: CountriesFeature.State(sections: sections)) {
            CountriesFeature()
        }

        await store.send(.sections(.element(id: .freeProfiles, action: .infoButtonTapped)))
        await store.receive(\.sections[id: .freeProfiles])
        await store.receive(\.presentFreeConnectionsInfo) {
            $0.destination = .freeConnectionsView(.init(countries: []))
        }
    }

    @Test("Country row showCountryUpsell routes to country upsell action")
    func countryRowShowCountryUpsellRoutesToPayments() async {
        let freeCountry = ServerGroupInfo(
            kind: .country(code: "US"),
            featureIntersection: [],
            featureUnion: [],
            minTier: .freeTier,
            maxTier: .freeTier,
            serverCount: 1,
            cityCount: 1,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )
        let sections: IdentifiedArrayOf<CountrySectionFeature.State> = [
            .init(
                id: .paidCountries,
                type: .countries,
                title: "Countries",
                rows: [
                    .country(
                        CountryFeature.State(
                            serverGroup: freeCountry,
                            serverType: .standard,
                            showCountryConnectButton: true,
                            showFeatureIcons: true,
                            serversFilter: .default
                        )
                    ),
                ],
                hasInfoButton: false,
                serversFilter: .default
            ),
        ]
        let countryRowID = sections[0].rows[0].id
        let store = TestStore(initialState: CountriesFeature.State(sections: sections)) {
            CountriesFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
        }

        await store.send(.sections(.element(id: .paidCountries, action: .rows(.element(id: countryRowID, action: .country(.showCountryUpsell("US")))))))
        await store.receive(\.presentCountryUpsell) {
            $0.destination = .payments(
                .init(
                    upsellModalType: .country(
                        countryCode: "US",
                        numberOfDevices: DomainConstants.maxDeviceCount,
                        numberOfCountries: 1
                    )
                )
            )
        }
    }

    @Test("Banner row tapped routes to all countries upsell")
    func bannerRowTappedRoutesToAllCountriesUpsell() async {
        let sections: IdentifiedArrayOf<CountrySectionFeature.State> = [
            .init(
                id: .allCountries,
                type: .countries,
                title: "Countries",
                rows: [
                    .banner(.init(bannerType: .upsell)),
                ],
                hasInfoButton: false,
                serversFilter: .default
            ),
        ]
        let bannerRowID = sections[0].rows[0].id
        let store = TestStore(initialState: CountriesFeature.State(sections: sections)) {
            CountriesFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
        }

        await store.send(.sections(.element(id: .allCountries, action: .rows(.element(id: bannerRowID, action: .banner(.tapped))))))
        await store.receive(\.presentAllCountriesUpsell) {
            $0.destination = .payments(
                .init(upsellModalType: .allCountries(numberOfServers: 1, numberOfCountries: 1))
            )
        }
    }

    @Test("Present free connections includes free-tier country names")
    func presentFreeConnectionsIncludesFreeTierCountries() async {
        let freeCountry = ServerGroupInfo(
            kind: .country(code: "US"),
            featureIntersection: [],
            featureUnion: [],
            minTier: .freeTier,
            maxTier: .freeTier,
            serverCount: 1,
            cityCount: 1,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )
        let paidCountry = ServerGroupInfo(
            kind: .country(code: "CH"),
            featureIntersection: [],
            featureUnion: [],
            minTier: .paidTier,
            maxTier: .paidTier,
            serverCount: 1,
            cityCount: 1,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )

        let sections: IdentifiedArrayOf<CountrySectionFeature.State> = [
            .init(
                id: .paidCountries,
                type: .countries,
                title: "Countries",
                rows: [
                    .country(
                        CountryFeature.State(
                            serverGroup: freeCountry,
                            serverType: .standard,
                            showCountryConnectButton: true,
                            showFeatureIcons: true,
                            serversFilter: .default
                        )
                    ),
                    .country(
                        CountryFeature.State(
                            serverGroup: paidCountry,
                            serverType: .standard,
                            showCountryConnectButton: true,
                            showFeatureIcons: true,
                            serversFilter: .default
                        )
                    ),
                ],
                hasInfoButton: false,
                serversFilter: .default
            ),
        ]

        let store = TestStore(initialState: CountriesFeature.State(sections: sections)) {
            CountriesFeature()
        }

        await store.send(.presentFreeConnectionsInfo) {
            $0.destination = .freeConnectionsView(.init(countries: [
                .init(
                    code: "US",
                    name: LocalizationUtility.default.countryName(forCode: "US") ?? Localizable.unavailable
                ),
            ]))
        }
    }

    @Test("Free connections upgrade opens subscription management and dismisses sheet")
    func freeConnectionsUpgradeOpensSubscriptionManagement() async {
        var state = CountriesFeature.State(sections: [])
        state.destination = .freeConnectionsView(.mock)

        let store = TestStore(initialState: state) {
            CountriesFeature()
        }

        await store.send(.destination(.presented(.freeConnectionsView(.upgradeTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.presentSubscriptionManagement) {
            $0.destination = .payments(
                .init(presentationKind: .directSubscriptionManagement)
            )
        }
    }

    // MARK: - Discourage Secure Core Flow Tests

    @Test("Discourage secure core activate when disconnected applies toggle")
    func discourageSecureCoreActivateWhenDisconnected() async {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

        var state = CountriesFeature.State(sections: [])
        state.destination = .discourageSecureCoreView(.init())

        let store = TestStore(initialState: state) {
            CountriesFeature()
        }

        await store.send(.destination(.presented(.discourageSecureCoreView(.activateTapped))))
        await store.receive(\.applySecureCoreToggle)
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
    }

    @Test("Discourage secure core activate when connected shows alert")
    func discourageSecureCoreActivateWhenConnectedShowsAlert() async {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .connected(.defaultFastest, nil)

        var state = CountriesFeature.State(sections: [])
        state.destination = .discourageSecureCoreView(.init())

        let store = TestStore(initialState: state) {
            CountriesFeature()
        }

        await store.send(.destination(.presented(.discourageSecureCoreView(.activateTapped)))) {
            $0.alert = AlertState(
                title: { TextState(Localizable.warning) },
                actions: {
                    ButtonState(
                        action: .send(.disconnectAndToggle),
                        label: { TextState(Localizable.continue) }
                    )
                    ButtonState(
                        role: .cancel,
                        action: .send(.cancel),
                        label: { TextState(Localizable.cancel) }
                    )
                },
                message: { TextState(Localizable.viewToggleWillCauseDisconnect) }
            )
        }
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
    }

    // MARK: - State Computed Properties Tests

    @Test("isConnectedToVPN returns true when connected")
    func isConnectedToVPNWhenConnected() {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .connected(.defaultFastest, nil)

        let state = CountriesFeature.State(sections: [])
        #expect(state.isConnectedToVPN)
    }

    @Test("isConnectedToVPN returns false when disconnected")
    func isConnectedToVPNWhenDisconnected() {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

        let state = CountriesFeature.State(sections: [])
        #expect(!state.isConnectedToVPN)
    }

    @Test("enableViewToggle returns false when connecting")
    func enableViewToggleWhenConnecting() {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .connecting(.defaultFastest, nil)

        let state = CountriesFeature.State(sections: [])
        #expect(!state.enableViewToggle)
    }

    @Test("enableViewToggle returns true when not connecting")
    func enableViewToggleWhenNotConnecting() {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus = .disconnected

        let state = CountriesFeature.State(sections: [])
        #expect(state.enableViewToggle)
    }
}
