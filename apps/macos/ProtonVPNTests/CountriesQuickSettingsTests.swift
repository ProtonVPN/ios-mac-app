//
//  Created on 30/03/2026 by Max Kupetskyi.
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
import Testing

@MainActor
@Suite
struct CountriesQuickSettingsTests {
    @Test("each quick setting has distinct detail options")
    func quickSettingDetailOptionsDifferByType() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .secureCoreDisplay, tier: .paidTier, from: $0)
            )
            $0.secureCore.isSelected = true
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .netShieldDisplay, tier: .paidTier, from: $0)
            )
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.buttonTapped(.killSwitchDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .killSwitchDisplay, tier: .paidTier, from: $0)
            )
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = true
            $0.portForwarding.isSelected = false
        }

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .portForwardingDisplay, tier: .paidTier, from: $0)
            )
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = true
        }
    }

    @Test("free tier marks paid quick setting options")
    func freeTierRequiresUpgradeForPaidOptions() async {
        let store = makeStore(userTier: .freeTier)

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .secureCoreDisplay, tier: .freeTier, from: $0)
            )
            $0.secureCore.isSelected = true
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .netShieldDisplay, tier: .freeTier, from: $0)
            )
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
        }

        await store.send(.buttonTapped(.killSwitchDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .killSwitchDisplay, tier: .freeTier, from: $0)
            )
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = true
        }

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .portForwardingDisplay, tier: .freeTier, from: $0)
            )
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = true
        }
    }

    @Test("paid tier does not require upgrade for paid options")
    func paidTierDoesNotRequireUpgradeForPaidOptions() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .secureCoreDisplay, tier: .paidTier, from: $0)
            )
            $0.secureCore.isSelected = true
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .netShieldDisplay, tier: .paidTier, from: $0)
            )
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
        }

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(
                Self.expectedDetail(type: .portForwardingDisplay, tier: .paidTier, from: $0)
            )
            $0.netShield.isSelected = false
            $0.portForwarding.isSelected = true
        }
    }

    private func makeStore(userTier: Int) -> TestStoreOf<QuickSettingsFeature> {
        TestStore(initialState: .init()) {
            QuickSettingsFeature(environment: .init(
                refreshUserTier: { userTier },
                performOptionSelection: { _, _, dismiss in dismiss() },
                initialNetShieldStats: { .zero(enabled: false) }
            ))
        }
    }

    private static func expectedDetail(
        type: QuickSettingType,
        tier: Int,
        from state: QuickSettingsFeature.State
    ) -> QuickSettingDetailFeature.State {
        .init(
            type: type,
            userTier: tier,
            secureCoreEnabled: state.secureCore.isEnabled,
            netShieldType: state.netShield.type,
            killSwitchEnabled: state.killSwitch.isEnabled,
            portForwardingEnabled: state.portForwarding.isEnabled,
            netShieldStatsEnabled: state.netShield.isStatsEnabled,
            netShieldStats: state.netShield.stats,
            connectionInfo: state.portForwarding.connectionInfo,
            visibleQuickSettingTypes: visibleTypes(from: state)
        )
    }

    private static func visibleTypes(from state: QuickSettingsFeature.State) -> [QuickSettingType] {
        var types: [QuickSettingType] = [.secureCoreDisplay]
        if state.netShield.isVisible { types.append(.netShieldDisplay) }
        types.append(.killSwitchDisplay)
        if state.portForwarding.isVisible { types.append(.portForwardingDisplay) }
        return types
    }
}
