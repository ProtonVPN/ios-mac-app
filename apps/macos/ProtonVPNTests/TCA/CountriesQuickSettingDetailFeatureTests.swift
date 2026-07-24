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

import ComposableArchitecture
import Domain
import Foundation
import NetShield
@testable import ProtonVPN
import Strings
import Testing

@MainActor
struct CountriesQuickSettingDetailFeatureTests {
    @Shared(.connectionProtocol) var connectionProtocol

    init() {
        $connectionProtocol.withLock { $0 = .smartProtocol }
    }

    @Test("option tap delegates selected option and type")
    func optionTappedDelegatesSelection() async {
        let store = TestStore(initialState: makeState(type: .netShieldDisplay)) {
            QuickSettingDetailFeature()
        }

        await store.send(.optionTapped(.netShield(.level2)))
        await store.receive(\.delegate.option)
    }

    @Test("upgrade tap delegates selected type")
    func upgradeTappedDelegatesType() async {
        let store = TestStore(initialState: makeState(type: .secureCoreDisplay)) {
            QuickSettingDetailFeature()
        }

        await store.send(.upgradeTapped)
        await store.receive(\.delegate.upgrade)
    }

    @Test("learn more opens secure core support link")
    func learnMoreSecureCoreOpensLink() async {
        var openedURL: URL?
        let store = TestStore(initialState: makeState(type: .secureCoreDisplay)) {
            QuickSettingDetailFeature()
        } withDependencies: {
            $0.linkOpener.open = { openedURL = $0 }
        }

        await store.send(.learnMoreTapped)
        #expect(openedURL == URL(string: VPNLink.learnMore.urlString))
    }

    @Test("learn more opens netshield support link")
    func learnMoreNetShieldOpensLink() async {
        var openedURL: URL?
        let store = TestStore(initialState: makeState(type: .netShieldDisplay)) {
            QuickSettingDetailFeature()
        } withDependencies: {
            $0.linkOpener.open = { openedURL = $0 }
        }

        await store.send(.learnMoreTapped)
        #expect(openedURL == URL(string: VPNLink.netshieldSupport.urlString))
    }

    @Test("learn more opens kill switch support link")
    func learnMoreKillSwitchOpensLink() async {
        var openedURL: URL?
        let store = TestStore(initialState: makeState(type: .killSwitchDisplay)) {
            QuickSettingDetailFeature()
        } withDependencies: {
            $0.linkOpener.open = { openedURL = $0 }
        }

        await store.send(.learnMoreTapped)
        #expect(openedURL == URL(string: VPNLink.killSwitchSupport.urlString))
    }

    @Test("learn more opens port forwarding support link")
    func learnMorePortForwardingOpensLink() async {
        var openedURL: URL?
        let store = TestStore(initialState: makeState(type: .portForwardingDisplay)) {
            QuickSettingDetailFeature()
        } withDependencies: {
            $0.linkOpener.open = { openedURL = $0 }
        }

        await store.send(.learnMoreTapped)
        #expect(openedURL == URL(string: VPNLink.portForwardingSupport.urlString))
    }

    @Test("Advanced kill switch option is disabled while IKEv2 is selected")
    func advancedOptionDisabledOverIke() {
        $connectionProtocol.withLock { $0 = .vpnProtocol(.ike) }
        let state = makeState(type: .killSwitchDisplay)

        #expect(state.advancedKillSwitchUnavailable)
        let advanced = state.selectedOptions.first { $0.id == .killSwitchAdvanced }
        #expect(advanced?.isEnabled == false)
        #expect(state.killSwitchStatusMessages.contains {
            $0.text == Localizable.killSwitchAdvancedUnavailableProtocolDescription
        })
    }

    @Test("Advanced kill switch option stays enabled for other protocols")
    func advancedOptionEnabledForOtherProtocols() {
        $connectionProtocol.withLock { $0 = .smartProtocol }
        let state = makeState(type: .killSwitchDisplay)

        #expect(!state.advancedKillSwitchUnavailable)
        let advanced = state.selectedOptions.first { $0.id == .killSwitchAdvanced }
        #expect(advanced?.isEnabled == true)
        #expect(!state.killSwitchStatusMessages.contains {
            $0.text == Localizable.killSwitchAdvancedUnavailableProtocolDescription
        })
    }

    @Test("Tapping the disabled Advanced option is ignored")
    func advancedTapIgnoredOverIke() async {
        $connectionProtocol.withLock { $0 = .vpnProtocol(.ike) }
        let store = TestStore(initialState: makeState(type: .killSwitchDisplay)) {
            QuickSettingDetailFeature()
        }

        // The exhaustive store fails this test if the tap produces a delegate action.
        await store.send(.optionTapped(.killSwitchAdvanced))
    }

    private func makeState(type: QuickSettingType) -> QuickSettingDetailFeature.State {
        .init(
            type: type,
            secureCoreEnabled: false,
            netShieldType: .off,
            killSwitchMode: .off,
            isConnected: false,
            portForwardingEnabled: false,
            netShieldStatsEnabled: false,
            netShieldStats: .zero(enabled: false),
            connectionInfo: .portForwardingStatus(enabled: false, supportsP2P: false, isConnected: false),
            visibleQuickSettingTypes: [.secureCoreDisplay, .netShieldDisplay, .killSwitchDisplay, .portForwardingDisplay],
            isBusinessAccount: false
        )
    }
}
