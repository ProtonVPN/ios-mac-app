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
@testable import Countries
import Domain
import DomainTestSupport
import LegacyCommon
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
        }

        await store.send(.secureCoreToggleRequested) {
            $0.alert = AlertState(
                title: { TextState("Upsell screen Payments") }
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
