//
//  Created on 19/05/2026 by Max Kupetskyi.
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
import Connection
import Domain
import Foundation
import NetShield
import Strings
import SwiftUI
import Theme
import VPNAppCore
import VPNShared

@Reducer
struct QuickSettingDetailFeature {
    @ObservableState
    struct State: Equatable {
        let type: QuickSettingType
        var secureCoreEnabled: Bool
        var netShieldType: NetShieldType
        var killSwitchMode: KillSwitchMode
        var isConnected: Bool
        var portForwardingEnabled: Bool
        var netShieldStatsEnabled: Bool
        var netShieldStats: NetShieldModel
        var connectionInfo: ConnectionInfo
        var visibleQuickSettingTypes: [QuickSettingType]
        /// Per-account NetShield feature settings (from `VpnCredentials.netshield`). Drives per-level visibility for
        /// B2B accounts — levels gated off here are hidden entirely, not greyed out. Ignored for B2C accounts (where
        /// the server may report all-false even for users who have paid access via the regular tier).
        var netshieldSettings: NetShieldFeatureSettings?
        /// Whether the user's account is a Business plan. Per-account `netshieldSettings` are authoritative only when
        /// this is `true`; for B2C accounts (free or paid) we keep the full level list visible and rely on tier-based
        /// upsell affordances for free users.
        var isBusinessAccount: Bool

        @SharedReader(.userTier) var userTier: VpnTier?
        @SharedReader(.connectionProtocol) var connectionProtocol: ConnectionProtocol

        /// Advanced kill switch needs ProTUN's zero-peer blocking, which IKEv2 cannot provide.
        var advancedKillSwitchUnavailable: Bool {
            connectionProtocol == .vpnProtocol(.ike)
        }

        var selectedTitle: String {
            type.title
        }

        var selectedDescription: String {
            type.description
        }

        var selectedNote: String? {
            type.note
        }

        var netShieldBadgeModel: NetShieldModel {
            guard netShieldType.shouldMonitorStats() else {
                return .zero(enabled: false)
            }
            return netShieldStats
        }

        var showUpgradeButton: Bool {
            selectedOptions.contains(where: \.requiresUpdate)
        }

        var selectedOptions: [QuickSettingOptionRow] {
            switch type {
            case .secureCoreDisplay:
                [
                    .init(
                        id: .secureCoreOff,
                        title: Localizable.secureCoreStatusOff,
                        icon: Theme.Asset.Icons.lock.swiftUIImage,
                        isActive: !secureCoreEnabled,
                        requiresUpdate: false
                    ),
                    .init(
                        id: .secureCoreOn,
                        title: Localizable.secureCoreStatusOn,
                        icon: Theme.Asset.Icons.locks.swiftUIImage,
                        isActive: secureCoreEnabled,
                        requiresUpdate: userTier.isFree
                    ),
                ]
            case .netShieldDisplay:
                netShieldOptions
            case .killSwitchDisplay:
                [
                    .init(
                        id: .killSwitchOff,
                        title: Localizable.killSwitchStatusOff,
                        icon: Theme.Asset.Icons.switchOff.swiftUIImage,
                        isActive: killSwitchMode == .off,
                        requiresUpdate: false
                    ),
                    .init(
                        id: .killSwitchStandard,
                        title: Localizable.killSwitchOptionStandard,
                        icon: Theme.Asset.Icons.switchOn.swiftUIImage,
                        isActive: killSwitchMode == .standard,
                        requiresUpdate: false
                    ),
                    .init(
                        id: .killSwitchAdvanced,
                        title: Localizable.killSwitchOptionAdvanced,
                        icon: Theme.Asset.Icons.switchOnLock.swiftUIImage,
                        isActive: killSwitchMode == .advanced,
                        isEnabled: !advancedKillSwitchUnavailable,
                        requiresUpdate: false
                    ),
                ]
            case .portForwardingDisplay:
                [
                    .init(
                        id: .portForwardingOff,
                        title: Localizable.portForwardingStatusOff,
                        icon: Theme.Asset.Icons.arrowUpBounceLeft.swiftUIImage,
                        isActive: !portForwardingEnabled,
                        requiresUpdate: false
                    ),
                    .init(
                        id: .portForwardingOn,
                        title: Localizable.portForwardingStatusOn,
                        icon: Theme.Asset.Icons.arrowsSwitch.swiftUIImage,
                        isActive: portForwardingEnabled,
                        requiresUpdate: userTier.isFree
                    ),
                ]
            }
        }

        /// NetShield options, filtered for visibility:
        ///
        /// - Globally-disabled levels (currently `.level3` when the kill-switch flag is off) are always hidden,
        ///   regardless of tier or business status — there's no upsell for a feature that doesn't exist yet.
        /// - For B2B accounts, per-account `netshieldSettings` further hide levels the plan doesn't include.
        /// - For B2C accounts (free or paid), the full level list stays visible. Free users see paid levels with the
        ///   existing upsell affordance via `requiresUpdate`.
        private var netShieldOptions: [QuickSettingOptionRow] {
            let rows: [(level: NetShieldType, title: String, icon: Image)] = [
                (.off, Localizable.quickSettingsNetshieldOptionOff, Theme.Asset.Icons.shield.swiftUIImage),
                (.level1, Localizable.quickSettingsNetshieldOptionLevel1, Theme.Asset.Icons.shieldHalfFilled.swiftUIImage),
                (.level2, Localizable.quickSettingsNetshieldOptionLevel2, Theme.Asset.Icons.shieldFilled.swiftUIImage),
                (.level3, Localizable.quickSettingsNetshieldOptionLevel3, Theme.Asset.Icons.shieldFilled.swiftUIImage),
            ]
            return rows
                .filter { !$0.level.isHidden(by: netshieldSettings, isBusiness: isBusinessAccount) }
                .map { row in
                    QuickSettingOptionRow(
                        id: .netShield(row.level),
                        title: row.title,
                        icon: row.icon,
                        isActive: netShieldType == row.level,
                        requiresUpdate: row.level != .off && userTier.isFree
                    )
                }
        }

        /// Kill Switch status message(s) + LAN hint shown below the picker rows (VPN status x KS mode) matrix. Empty
        /// for non-KS quick settings.
        var killSwitchStatusMessages: [KillSwitchStatusMessage] {
            guard type == .killSwitchDisplay else { return [] }
            let lanHint = KillSwitchStatusMessage(
                text: Localizable.quickSettingsKillSwitchNote,
                icon: Theme.Asset.Icons.infoCircleFilled.swiftUIImage,
                iconColor: Color(.icon, .weak)
            )
            let ipExposed = KillSwitchStatusMessage(
                text: Localizable.killSwitchStatusExposed,
                icon: Theme.Asset.Icons.infoCircleFilled.swiftUIImage,
                iconColor: Color(.icon, .weak)
            )
            let messages: [KillSwitchStatusMessage] = switch killSwitchMode {
            case .off:
                [ipExposed]
            case .standard where isConnected:
                [
                    KillSwitchStatusMessage(
                        text: Localizable.killSwitchStatusStandard,
                        icon: Theme.Asset.Icons.checkmarkCircleFilled.swiftUIImage,
                        iconColor: Color(.icon, .success)
                    ),
                    lanHint,
                ]
            case .standard:
                [ipExposed, lanHint]
            case .advanced where isConnected:
                [
                    KillSwitchStatusMessage(
                        text: Localizable.killSwitchStatusAdvancedBlocksAll,
                        icon: Theme.Asset.Icons.checkmarkCircleFilled.swiftUIImage,
                        iconColor: Color(.icon, .success)
                    ),
                    KillSwitchStatusMessage(
                        text: Localizable.killSwitchStatusAdvancedApplies,
                        icon: Theme.Asset.Icons.exclamationCircleFilled.swiftUIImage,
                        iconColor: Color(.icon, .warning)
                    ),
                    lanHint,
                ]
            case .advanced:
                [
                    KillSwitchStatusMessage(
                        text: Localizable.killSwitchStatusAdvancedDisablesInternet,
                        icon: Theme.Asset.Icons.circleSlash.swiftUIImage,
                        iconColor: Color(.icon, .weak)
                    ),
                    KillSwitchStatusMessage(
                        text: Localizable.killSwitchBulletAdvancedRecover,
                        icon: Theme.Asset.Icons.exclamationCircleFilled.swiftUIImage,
                        iconColor: Color(.icon, .warning)
                    ),
                    lanHint,
                ]
            }
            guard advancedKillSwitchUnavailable else { return messages }
            return messages + [
                KillSwitchStatusMessage(
                    text: Localizable.killSwitchAdvancedUnavailableProtocolDescription,
                    icon: Theme.Asset.Icons.infoCircleFilled.swiftUIImage,
                    iconColor: Color(.icon, .weak)
                ),
            ]
        }

        var portForwardingState: PortForwardingVCState {
            switch connectionInfo {
            case let .portForwardingStatus(enabled, supportsP2P, isConnected):
                switch (isConnected, enabled, supportsP2P) {
                case (true, true, true):
                    .connectedToP2P
                case (true, true, false):
                    .connectedNotToP2P
                case (true, false, _):
                    .connectedNoPf
                case (false, true, _):
                    .notConnected(pfEnabled: true)
                case (false, false, _):
                    .notConnected(pfEnabled: false)
                }
            case .pfError:
                .error
            }
        }

        static func makeDetailState(type: QuickSettingType, from state: QuickSettingsFeature.State) -> QuickSettingDetailFeature.State {
            @Dependency(\.credentialsProvider) var credentialsProvider
            return QuickSettingDetailFeature.State(
                type: type,
                secureCoreEnabled: state.secureCore.isEnabled,
                netShieldType: state.netShield.type,
                killSwitchMode: state.killSwitch.killSwitchMode,
                isConnected: state.killSwitch.connectionState.isConnected,
                portForwardingEnabled: state.portForwarding.isEnabled,
                netShieldStatsEnabled: state.netShield.isStatsEnabled,
                netShieldStats: state.netShield.stats,
                connectionInfo: state.portForwarding.connectionInfo,
                visibleQuickSettingTypes: visibleQuickSettingTypes(from: state),
                netshieldSettings: credentialsProvider.credentials?.netshield,
                isBusinessAccount: credentialsProvider.credentials?.isBusiness ?? false
            )
        }

        private static func visibleQuickSettingTypes(from state: QuickSettingsFeature.State) -> [QuickSettingType] {
            var types: [QuickSettingType] = [.secureCoreDisplay]
            if state.netShield.isVisible { types.append(.netShieldDisplay) }
            if state.killSwitch.isVisible { types.append(.killSwitchDisplay) }
            if state.portForwarding.isVisible { types.append(.portForwardingDisplay) }
            return types
        }
    }

    @CasePathable
    enum Action {
        case learnMoreTapped
        case optionTapped(QuickSettingOptionID)
        case upgradeTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate {
            case option(QuickSettingType, QuickSettingOptionID)
            case upgrade(QuickSettingType)
        }
    }

    @Dependency(\.linkOpener) var linkOpener

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .learnMoreTapped:
                linkOpener.open(state.type.learnMoreLink)
                return .none
            case .optionTapped(.killSwitchAdvanced) where state.advancedKillSwitchUnavailable:
                return .none
            case let .optionTapped(option):
                return .send(.delegate(.option(state.type, option)))
            case .upgradeTapped:
                return .send(.delegate(.upgrade(state.type)))
            case .delegate:
                return .none
            }
        }
    }
}

struct QuickSettingOptionRow: Identifiable {
    let id: QuickSettingOptionID
    let title: String
    let icon: Image
    let isActive: Bool
    var isEnabled = true
    let requiresUpdate: Bool
}

/// A single Kill Switch status line (icon + text) shown below the picker rows
struct KillSwitchStatusMessage: Identifiable {
    var id: String {
        text
    }

    let text: String
    let icon: Image
    let iconColor: Color?
}
