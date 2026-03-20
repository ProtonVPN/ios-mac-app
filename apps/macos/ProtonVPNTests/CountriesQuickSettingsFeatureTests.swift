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
import NetShield
import Testing

@testable import ProtonVPN

@MainActor
@Suite
struct CountriesQuickSettingsFeatureTests {
    @Test("button tap opens detail and selects active quick setting")
    func buttonTapOpensDetailAndSelectsType() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, tier: .paidTier, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("tapping active quick setting closes detail and clears selection")
    func tappingActiveSettingClosesDetail() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, tier: .paidTier, from: $0))
            $0.secureCore.isSelected = true
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = nil
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("upgrade delegate calls environment callback with selected type")
    func upgradeDelegatePresentsUpsell() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, tier: .paidTier, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = true
        }

        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.upgrade(.portForwardingDisplay)))))) {
            $0.destination = .upsell(.init(modalType: .portForwarding))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("dismiss details does not clear upsell destination")
    func dismissDetailsDoesNotClearUpsellDestination() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, tier: .paidTier, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = true
        }

        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.upgrade(.portForwardingDisplay)))))) {
            $0.destination = .upsell(.init(modalType: .portForwarding))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.dismissDetails)
    }

    @Test("option delegate forwards selected type and option")
    func optionDelegateForwardsSelection() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, tier: .paidTier, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(
            .destination(
                .presented(
                    .quickSettingDetail(
                        .delegate(.option(.netShieldDisplay, .netShield(.level1)))
                    )
                )
            )
        )
        await store.receive(\.dismissDetails) {
            $0.destination = nil
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("free user detail marks upgrade for paid options")
    func freeUserDetailRequiresUpgrade() async {
        let store = makeStore(userTier: .freeTier)

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, tier: .freeTier, from: $0))
            $0.secureCore.isSelected = true
        }
    }

    @Test("free user secure core option shows secure core upsell")
    func freeUserSecureCoreOptionShowsUpsell() async {
        let store = makeStore(userTier: .freeTier)

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, tier: .freeTier, from: $0))
            $0.secureCore.isSelected = true
        }

        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.option(.secureCoreDisplay, .secureCoreOn)))))) {
            $0.destination = .upsell(.init(modalType: .secureCore))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("free user netshield paid option shows netshield upsell")
    func freeUserNetShieldPaidOptionShowsUpsell() async {
        let store = makeStore(userTier: .freeTier)

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, tier: .freeTier, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.option(.netShieldDisplay, .netShield(.level1))))))) {
            $0.destination = .upsell(.init(modalType: .netShield))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("free user port forwarding option shows port forwarding upsell")
    func freeUserPortForwardingOptionShowsUpsell() async {
        let store = makeStore(userTier: .freeTier)

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, tier: .freeTier, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = true
        }

        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.option(.portForwardingDisplay, .portForwardingOn)))))) {
            $0.destination = .upsell(.init(modalType: .portForwarding))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("paid user detail does not require upgrade for paid options")
    func paidUserDetailDoesNotRequireUpgrade() async {
        let store = makeStore(userTier: .paidTier)

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, tier: .paidTier, from: $0))
            $0.portForwarding.isSelected = true
        }
    }

    private func makeStore(
        userTier: Int,
        performOptionSelection: @escaping @Sendable (QuickSettingType, QuickSettingOptionID, @escaping @Sendable () -> Void) -> Void = { _, _, dismiss in dismiss() }
    ) -> TestStoreOf<QuickSettingsFeature> {
        TestStore(initialState: .init()) {
            QuickSettingsFeature(environment: .init(
                refreshUserTier: { userTier },
                performOptionSelection: performOptionSelection,
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
