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
import Testing

@testable import ProtonVPN

@MainActor
@Suite
struct CountriesQuickSettingDetailFeatureTests {
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

    private func makeState(type: QuickSettingType) -> QuickSettingDetailFeature.State {
        .init(
            type: type,
            secureCoreEnabled: false,
            netShieldType: .off,
            killSwitchEnabled: false,
            portForwardingEnabled: false,
            netShieldStatsEnabled: false,
            netShieldStats: .zero(enabled: false),
            connectionInfo: .portForwardingStatus(enabled: false, supportsP2P: false, isConnected: false),
            visibleQuickSettingTypes: [.secureCoreDisplay, .netShieldDisplay, .killSwitchDisplay, .portForwardingDisplay]
        )
    }
}
