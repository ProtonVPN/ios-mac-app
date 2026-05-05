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
import Dependencies
import Domain
import NetShield
@testable import ProtonVPN
import Sharing
import Testing

@MainActor
struct CountriesQuickSettingsFeatureTests {
    @Test("each quick setting has distinct detail options")
    func quickSettingDetailOptionsDifferByType() async {
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = makeStore()

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, from: $0))
            $0.secureCore.isSelected = true
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.buttonTapped(.killSwitchDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .killSwitchDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = true
            $0.portForwarding.isSelected = false
        }

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = true
        }
    }

    @Test("tapping active quick setting closes detail and clears selection")
    func tappingActiveSettingClosesDetail() async {
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = makeStore()

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, from: $0))
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
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = makeStore()

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, from: $0))
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
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = makeStore()

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, from: $0))
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
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = makeStore()

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
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

    @Test("free tier marks paid quick setting options")
    func freeTierRequiresUpgradeForPaidOptions() async {
        @Shared(.userTier) var userTier: Int? = .freeTier
        let store = makeStore()

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, from: $0))
            $0.secureCore.isSelected = true
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
        }

        await store.send(.buttonTapped(.killSwitchDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .killSwitchDisplay, from: $0))
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = true
        }

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, from: $0))
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = true
        }
    }

    @Test("free user secure core option shows secure core upsell")
    func freeUserSecureCoreOptionShowsUpsell() async {
        @Shared(.userTier) var userTier: Int? = .freeTier
        let store = makeStore()

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, from: $0))
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

    @Test("paid user secure core option shows discourage secure core view when enabled")
    func paidUserSecureCoreOptionShowsDiscourageView() async {
        @Shared(.discourageSecureCore) var discourageSecureCore = true
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = makeStore()

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, from: $0))
            $0.secureCore.isSelected = true
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.option(.secureCoreDisplay, .secureCoreOn)))))) {
            $0.destination = .discourageSecureCoreView(.init())
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
    }

    @Test("discourage secure core activate performs selection and dismisses")
    func discourageSecureCoreActivatePerformsSelectionAndDismisses() async {
        @Shared(.discourageSecureCore) var discourageSecureCore = true
        @Shared(.userTier) var userTier: Int? = .paidTier

        var receivedSelection: (QuickSettingType, QuickSettingOptionID)?
        let store = makeStore(
            performOptionSelection: { type, option, dismiss in
                receivedSelection = (type, option)
                dismiss()
            }
        )

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, from: $0))
            $0.secureCore.isSelected = true
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.option(.secureCoreDisplay, .secureCoreOn)))))) {
            $0.destination = .discourageSecureCoreView(.init())
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.destination(.presented(.discourageSecureCoreView(.delegate(.activateTapped))))) {
            $0.destination = nil
        }
        await store.receive(\.dismissDetails)
        #expect(receivedSelection?.0 == .secureCoreDisplay)
        #expect(receivedSelection?.1 == .secureCoreOn)
    }

    @Test("free user netshield paid option shows netshield upsell")
    func freeUserNetShieldPaidOptionShowsUpsell() async {
        @Shared(.userTier) var userTier: Int? = .freeTier
        let store = makeStore()

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
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
        @Shared(.userTier) var userTier: Int? = .freeTier
        let store = makeStore()

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, from: $0))
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

    @Test("paid tier does not require upgrade for paid options")
    func paidTierDoesNotRequireUpgradeForPaidOptions() async {
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = makeStore()

        await store.send(.buttonTapped(.secureCoreDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .secureCoreDisplay, from: $0))
            $0.secureCore.isSelected = true
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
        }

        await store.send(.buttonTapped(.portForwardingDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .portForwardingDisplay, from: $0))
            $0.netShield.isSelected = false
            $0.portForwarding.isSelected = true
        }
    }

    @Test("netshield detail stays in sync with external netshield updates")
    func netShieldDetailSyncsOnExternalUpdates() async {
        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = TestStore(initialState: QuickSettingsFeature.State(
            netShield: .init(
                isSelected: false,
                type: .level2,
                isVisible: false,
                isStatsEnabled: false,
                connectionInfo: .portForwardingStatus(
                    enabled: false,
                    supportsP2P: false,
                    isConnected: false
                ),
                stats: .zero(enabled: false)
            )
        )) {
            QuickSettingsFeature(environment: .init(
                performOptionSelection: { _, _, dismiss in dismiss() },
                initialNetShieldStats: { .zero(enabled: false) }
            ))
        } withDependencies: {
            $0.netShieldPropertyProvider.getNetShieldType = { .off }
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }

        await store.send(.netShield(.updateNetShield)) {
            $0.netShield.type = .off
            $0.netShield.isVisible = true
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
        }
    }

    @Test("kill switch on presents conflict alert")
    func killSwitchOnPresentsConflictAlert() async {
        @Shared(.userTier) var userTier: Int? = .paidTier

        let store = makeStore()

        await store.send(.buttonTapped(.killSwitchDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .killSwitchDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = false
            $0.killSwitch.isSelected = true
            $0.portForwarding.isSelected = false
        }
        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.option(.killSwitchDisplay, .killSwitchOn)))))) {
            $0.alert = QuickSettingsFeature.killSwitchConflictAlert
        }
    }

    @Test("netshield option presents hermes conflict alert")
    func netShieldOptionPresentsHermesConflictAlert() async {
        @Shared(.userTier) var userTier: Int? = .paidTier

        let store = TestStore(initialState: QuickSettingsFeature.State()) {
            QuickSettingsFeature(environment: .init(
                performOptionSelection: { _, _, dismiss in dismiss() },
                initialNetShieldStats: { .zero(enabled: false) }
            ))
        } withDependencies: {
            $0.hermesClient.setIsEnabled(true)
        }

        await store.send(.buttonTapped(.netShieldDisplay)) {
            $0.destination = .quickSettingDetail(Self.expectedDetail(type: .netShieldDisplay, from: $0))
            $0.secureCore.isSelected = false
            $0.netShield.isSelected = true
            $0.killSwitch.isSelected = false
            $0.portForwarding.isSelected = false
        }
        await store.send(.destination(.presented(.quickSettingDetail(.delegate(.option(.netShieldDisplay, .netShield(.level1))))))) {
            $0.alert = QuickSettingsFeature.hermesConflictAlert(level: .level1)
        }
    }

    private func makeStore(
        performOptionSelection: @escaping @Sendable (QuickSettingType, QuickSettingOptionID, @escaping @Sendable () -> Void) -> Void = { _, _, dismiss in dismiss() }
    ) -> TestStoreOf<QuickSettingsFeature> {
        TestStore(initialState: .init()) {
            QuickSettingsFeature(environment: .init(
                performOptionSelection: performOptionSelection,
                initialNetShieldStats: { .zero(enabled: false) }
            ))
        }
    }

    private static func expectedDetail(
        type: QuickSettingType,
        from state: QuickSettingsFeature.State
    ) -> QuickSettingDetailFeature.State {
        .init(
            type: type,
            secureCoreEnabled: state.secureCore.isEnabled,
            netShieldType: state.netShield.type,
            killSwitchEnabled: state.killSwitch.isEnabled,
            portForwardingEnabled: state.portForwarding.isEnabled,
            netShieldStatsEnabled: state.netShield.isStatsEnabled,
            netShieldStats: state.netShield.stats,
            connectionInfo: state.portForwarding.connectionInfo,
            visibleQuickSettingTypes: visibleTypes(from: state),
            netshieldSettings: .init(malware: true, adsAndTrackers: true, adultContent: true),
            isBusinessAccount: false
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
