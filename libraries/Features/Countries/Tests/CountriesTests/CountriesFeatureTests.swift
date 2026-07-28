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

import CommonNetworking
import ComposableArchitecture
import Connection
@testable import CountriesShared
import Domain
import DomainTestSupport
import Foundation
import Localization
import PaymentsShared
import PersistenceTestSupport
import Strings
import Testing
import VPNAppCore

private let _testLogical = Logical(
    id: "test-logical",
    name: "T#1",
    domain: "test.example",
    load: 0,
    entryCountryCode: "EU",
    exitCountryCode: "EU",
    tier: .free,
    score: 0,
    status: 1,
    feature: [],
    city: nil,
    state: nil,
    hostCountry: nil,
    translatedCity: nil,
    latitude: 0,
    longitude: 0,
    gatewayName: nil
)
private let _testEndpoint = ServerEndpoint(
    id: "test-endpoint",
    entryIp: "1.1.1.1",
    exitIp: "1.1.1.1",
    domain: "test.example",
    status: 1,
    label: nil,
    x25519PublicKey: nil,
    protocolEntries: nil
)
private let _testServer = Server(logical: _testLogical, endpoint: _testEndpoint)
private let _testIntent = ServerConnectionIntent(
    spec: .defaultFastest,
    server: _testServer,
    protocolConfiguration: .ike,
    features: AgentTunnelFeatures(
        netshield: .off,
        vpnAccelerator: true,
        natType: .moderateNAT,
        portForwarding: nil
    )
)

private extension ConnectionState {
    static var fakeConnected: ConnectionState {
        .connected(
            .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"], killSwitch: false),
            .init(currentPeer: .ca, connectionDate: .now, protocolConnectionData: .ike)
        )
    }

    static var fakeConnecting: ConnectionState {
        .connecting(.unresolved(ConnectionPreparationIntent(spec: .defaultFastest, acceptableProtocols: .ikev2)))
    }
}

@Suite("Countries Feature Tests")
@MainActor
struct CountriesFeatureTests {
    // MARK: - Secure Core Toggle Tests

    @Test("Secure core toggle works for paid user when disconnected")
    func secureCoreToggleWhenDisconnectedAndPaidUser() async {
        @SharedReader(.secureCoreToggle) var isSecureCore = false
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @SharedReader(.connectionState) var connectionState: ConnectionState = .disconnected
        @SharedReader(.discourageSecureCore) var discourageSecureCore = false

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested)
        await store.receive(\.applySecureCoreToggle)
    }

    @Test("Secure core toggle shows upsell for free user")
    func secureCoreToggleShowsUpsellForFreeUser() async {
        @SharedReader(.secureCoreToggle) var isSecureCore = false
        @SharedReader(.userTier) var userTier: VpnTier? = .free
        @SharedReader(.connectionState) var connectionState: ConnectionState = .disconnected

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
        @SharedReader(.secureCoreToggle) var isSecureCore = false
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @SharedReader(.connectionState) var connectionState: ConnectionState = .disconnected
        @SharedReader(.discourageSecureCore) var discourageSecureCore = true

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.destination = .discourageSecureCoreView(.init())
        }
    }

    @Test("Secure core ON + discourage=false + connected → short alert with same-country message")
    func secureCoreToggleOnConnectedNoDiscourageShowsAlert() async {
        @SharedReader(.secureCoreToggle) var isSecureCore = false
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .fakeConnected }
        @SharedReader(.discourageSecureCore) var discourageSecureCore = false

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.alert = AlertState(
                title: { TextState(Localizable.warning) },
                actions: {
                    ButtonState(action: .send(.disconnectAndToggle), label: { TextState(Localizable.continue) })
                    ButtonState(role: .cancel, action: .send(.cancel), label: { TextState(Localizable.cancel) })
                },
                message: { TextState(Localizable.viewToggleOnReconnectSameCountry) }
            )
        }
    }

    @Test("Secure core ON + discourage=true + connected → discourage with same-country notice")
    func secureCoreToggleOnConnectedWithDiscourageShowsViewWithNotice() async {
        @SharedReader(.secureCoreToggle) var isSecureCore = false
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .fakeConnected }
        @SharedReader(.discourageSecureCore) var discourageSecureCore = true

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.destination = .discourageSecureCoreView(
                .init(reconnectNotice: Localizable.viewToggleOnReconnectSameCountry)
            )
        }
    }

    @Test("Secure core ON + discourage=true + not connected → discourage without notice")
    func secureCoreToggleOnDisconnectedWithDiscourageShowsViewWithoutNotice() async {
        @SharedReader(.secureCoreToggle) var isSecureCore = false
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @SharedReader(.connectionState) var connectionState: ConnectionState = .disconnected
        @SharedReader(.discourageSecureCore) var discourageSecureCore = true

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.destination = .discourageSecureCoreView(.init(reconnectNotice: nil))
        }
    }

    @Test("Secure core OFF + connected → short alert")
    func secureCoreToggleOffConnectedShowsAlert() async {
        @SharedReader(.secureCoreToggle) var isSecureCore = true
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .fakeConnected }

        let store = TestStore(initialState: CountriesFeature.State(sections: [])) {
            CountriesFeature()
        }

        await store.send(.secureCoreToggleRequested) {
            $0.alert = AlertState(
                title: { TextState(Localizable.warning) },
                actions: {
                    ButtonState(action: .send(.disconnectAndToggle), label: { TextState(Localizable.continue) })
                    ButtonState(role: .cancel, action: .send(.cancel), label: { TextState(Localizable.cancel) })
                },
                message: { TextState(Localizable.viewToggleWillCauseDisconnect) }
            )
        }
    }

    @Test("Turning off secure core when disconnected applies toggle")
    func turningOffSecureCoreWhenDisconnected() async {
        @SharedReader(.secureCoreToggle) var isSecureCore = true
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }
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

        let countryName = "United States"
        let services: [VpnStreamingOption] = [
            VpnStreamingOption(name: "Netflix", icon: "netflix.png"),
            VpnStreamingOption(name: "Amazon Prime", icon: "amazonprime.png"),
            VpnStreamingOption(name: "Disney+", icon: "disneyplus.png"),
        ]

        await store.send(.showServersStreamingFeaturesInfo(countryName: countryName, services: services)) {
            $0.destination = .serversStreamingFeaturesInfo(
                ServersStreamingFeaturesFeature.State(
                    countryName: countryName,
                    streamingServices: IdentifiedArrayOf<StreamingServiceItem.State>(
                        uniqueElements: services.map {
                            StreamingServiceItem.State(service: $0, showImage: true)
                        }
                    )
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

    @Test("Country row tap shows city-state sheet when feature is enabled")
    func countryRowTapShowsCityStateSheet() async {
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        let group = ServerGroupInfo(
            kind: .country(code: "US"),
            featureIntersection: [],
            featureUnion: [],
            minTier: .paid,
            maxTier: .paid,
            serverCount: 1,
            cityCount: 1,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )
        let countryState = CountryFeature.State(
            serverGroup: group,
            serverType: .standard,
            showCountryConnectButton: true,
            showFeatureIcons: true,
            serversFilter: .default
        )
        let sections: IdentifiedArrayOf<CountrySectionFeature.State> = [
            .init(
                id: .allCountries,
                type: .countries,
                title: "All",
                rows: [.country(countryState)],
                hasInfoButton: false,
                serversFilter: .default
            ),
        ]
        let rowID = sections[0].rows[0].id

        let store = TestStore(initialState: CountriesFeature.State(sections: sections)) {
            CountriesFeature()
        }

        await store.send(.sections(.element(id: .allCountries, action: .rows(.element(id: rowID, action: .country(.rowTapped)))))) {
            $0.destination = .cityStateList(.init(countryCode: "US"))
        }
    }

    @Test("Gateway row tap navigates to country details")
    func gatewayRowTapNavigatesToCountryDetails() async {
        let group = ServerGroupInfo(
            kind: .gateway(name: "Gateway"),
            featureIntersection: [],
            featureUnion: [],
            minTier: .paid,
            maxTier: .paid,
            serverCount: 1,
            cityCount: 1,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )
        let countryState = CountryFeature.State(
            serverGroup: group,
            serverType: .standard,
            showCountryConnectButton: true,
            showFeatureIcons: true,
            serversFilter: .default
        )
        let sections: IdentifiedArrayOf<CountrySectionFeature.State> = [
            .init(
                id: .allCountries,
                type: .countries,
                title: "All",
                rows: [.country(countryState)],
                hasInfoButton: false,
                serversFilter: .default
            ),
        ]
        let rowID = sections[0].rows[0].id

        let store = TestStore(initialState: CountriesFeature.State(sections: sections)) {
            CountriesFeature()
        }

        await store.send(.sections(.element(id: .allCountries, action: .rows(.element(id: rowID, action: .country(.rowTapped)))))) {
            $0.path.append(.country(countryState))
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
            minTier: .free,
            maxTier: .free,
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
            minTier: .free,
            maxTier: .free,
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
            minTier: .paid,
            maxTier: .paid,
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
        @SharedReader(.connectionState) var connectionState: ConnectionState = .disconnected

        var state = CountriesFeature.State(sections: [])
        state.destination = .discourageSecureCoreView(.init())

        let store = TestStore(initialState: state) {
            CountriesFeature()
        }

        await store.send(.destination(.presented(.discourageSecureCoreView(.activateTapped))))
        await store.receive(\.destination.discourageSecureCoreView.delegate.activateTapped)
        await store.receive(\.applySecureCoreToggle)
    }

    @Test("Discourage secure core activate (while connected) dispatches applySecureCoreToggle")
    func discourageSecureCoreActivateWhileConnectedDispatchesApply() async {
        @SharedReader(.connectionState) var connectionState: ConnectionState = .fakeConnected

        var state = CountriesFeature.State(sections: [])
        state.destination = .discourageSecureCoreView(.init(reconnectNotice: nil))

        let store = TestStore(initialState: state) {
            CountriesFeature()
        }

        await store.send(.destination(.presented(.discourageSecureCoreView(.activateTapped))))
        await store.receive(\.destination.discourageSecureCoreView.delegate.activateTapped)
        await store.receive(\.applySecureCoreToggle)
    }

    // MARK: - State Computed Properties Tests

    @Test("isConnectedToVPN returns true when connected")
    func isConnectedToVPNWhenConnected() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .fakeConnected }
        let state = CountriesFeature.State(sections: [])
        #expect(state.isConnectedToVPN)
    }

    @Test("isConnectedToVPN returns false when disconnected")
    func isConnectedToVPNWhenDisconnected() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }
        let state = CountriesFeature.State(sections: [])
        #expect(!state.isConnectedToVPN)
    }

    @Test("enableViewToggle returns false when connecting")
    func enableViewToggleWhenConnecting() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .fakeConnecting }
        let state = CountriesFeature.State(sections: [])
        #expect(!state.enableViewToggle)
    }

    @Test("enableViewToggle returns true when not connecting")
    func enableViewToggleWhenNotConnecting() {
        @SharedReader(.connectionState) var connectionState: ConnectionState = .disconnected

        let state = CountriesFeature.State(sections: [])
        #expect(state.enableViewToggle)
    }
}
