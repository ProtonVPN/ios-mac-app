//
//  Created on 19/03/2026 by Max Kupetskyi.
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
import Ergonomics
import LegacyCommon
import NetShield
import Strings
import SwiftUI
import Theme
import VPNShared

@Reducer
struct QuickSettingDetailFeature {
    @ObservableState
    struct State: Equatable {
        let type: QuickSettingType
        var userTier: Int
        var secureCoreEnabled: Bool
        var netShieldType: NetShieldType
        var killSwitchEnabled: Bool
        var portForwardingEnabled: Bool
        var netShieldStatsEnabled: Bool
        var netShieldStats: NetShieldModel
        var connectionInfo: ConnectionInfo
        var visibleQuickSettingTypes: [QuickSettingType]

        var selectedTitle: String { type.title }
        var selectedDescription: String { type.description }
        var selectedNote: String? { type.note }

        var netShieldBadgeModel: NetShieldModel {
            guard netShieldType == .level2 else { return .zero(enabled: false) }
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
                        requiresUpdate: userTier.isFreeTier
                    ),
                ]
            case .netShieldDisplay:
                [
                    .init(
                        id: .netShield(.off),
                        title: Localizable.quickSettingsNetshieldOptionOff,
                        icon: Theme.Asset.Icons.shield.swiftUIImage,
                        isActive: netShieldType == .off,
                        requiresUpdate: false
                    ),
                    .init(
                        id: .netShield(.level1),
                        title: Localizable.quickSettingsNetshieldOptionLevel1,
                        icon: Theme.Asset.Icons.shieldHalfFilled.swiftUIImage,
                        isActive: netShieldType == .level1,
                        requiresUpdate: userTier.isFreeTier
                    ),
                    .init(
                        id: .netShield(.level2),
                        title: Localizable.quickSettingsNetshieldOptionLevel2,
                        icon: Theme.Asset.Icons.shieldFilled.swiftUIImage,
                        isActive: netShieldType == .level2,
                        requiresUpdate: userTier.isFreeTier
                    ),
                ]
            case .killSwitchDisplay:
                [
                    .init(
                        id: .killSwitchOff,
                        title: Localizable.killSwitchStatusOff,
                        icon: Theme.Asset.Icons.switchOff.swiftUIImage,
                        isActive: !killSwitchEnabled,
                        requiresUpdate: false
                    ),
                    .init(
                        id: .killSwitchOn,
                        title: Localizable.killSwitchStatusOn,
                        icon: Theme.Asset.Icons.switchOn.swiftUIImage,
                        isActive: killSwitchEnabled,
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
                        requiresUpdate: userTier.isFreeTier
                    ),
                ]
            }
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

        static func makeDetailState(type: QuickSettingType, userTier: Int, from state: QuickSettingsFeature.State) -> QuickSettingDetailFeature.State {
            QuickSettingDetailFeature.State(
                type: type,
                userTier: userTier,
                secureCoreEnabled: state.secureCore.isEnabled,
                netShieldType: state.netShield.type,
                killSwitchEnabled: state.killSwitch.isEnabled,
                portForwardingEnabled: state.portForwarding.isEnabled,
                netShieldStatsEnabled: state.netShield.isStatsEnabled,
                netShieldStats: state.netShield.stats,
                connectionInfo: state.portForwarding.connectionInfo,
                visibleQuickSettingTypes: visibleQuickSettingTypes(from: state)
            )
        }

        private static func visibleQuickSettingTypes(from state: QuickSettingsFeature.State) -> [QuickSettingType] {
            var types: [QuickSettingType] = [.secureCoreDisplay]
            if state.netShield.isVisible { types.append(.netShieldDisplay) }
            types.append(.killSwitchDisplay)
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

@Reducer
struct QuickSettingsFeature {
    @Reducer
    enum Destination {
        case quickSettingDetail(QuickSettingDetailFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?

        var secureCore = SecureCoreQuickSettingFeature.State(isSelected: false)
        var netShield = NetShieldQuickSettingFeature.State(
            isSelected: false,
            type: .off,
            isVisible: false,
            isStatsEnabled: false,
            connectionInfo: .portForwardingStatus(
                enabled: false,
                supportsP2P: false,
                isConnected: false
            ),
            stats: .zero(enabled: false)
        )
        var killSwitch = KillSwitchQuickSettingFeature.State(isSelected: false)
        var portForwarding = PortForwardingQuickSettingFeature.State(
            isSelected: false,
            isEnabled: false,
            isVisible: VPNFeatureFlagType.portForwarding.enabled
        )

        var activeType: QuickSettingType? {
            guard case let .quickSettingDetail(detail) = destination else { return nil }
            return detail.type
        }

        var isSearchDisabled: Bool { destination != nil }

        var netShieldBadgeVisible: Bool { netShield.badgeVisible }
        var netShieldBadgeModel: NetShieldModel { netShield.badgeModel }
        var netShieldBadgeText: String { netShield.badgeText }
    }

    enum Action {
        case secureCore(SecureCoreQuickSettingFeature.Action)
        case netShield(NetShieldQuickSettingFeature.Action)
        case killSwitch(KillSwitchQuickSettingFeature.Action)
        case portForwarding(PortForwardingQuickSettingFeature.Action)

        case startObserving
        case buttonTapped(QuickSettingType)
        case dismissDetails
        case destination(PresentationAction<Destination.Action>)
        case connectionInfoUpdated(ConnectionInfo)
    }

    struct Environment {
        var refreshUserTier: @Sendable () -> Int
        var performOptionSelection: @Sendable (QuickSettingType, QuickSettingOptionID, @escaping @Sendable () -> Void) -> Void
        var didTapUpgrade: @Sendable (QuickSettingType) -> Void
        var initialNetShieldStats: @Sendable () -> NetShieldModel
    }

    private let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.secureCore, action: \.secureCore) {
            SecureCoreQuickSettingFeature()
        }
        Scope(state: \.netShield, action: \.netShield) {
            NetShieldQuickSettingFeature()
        }
        Scope(state: \.killSwitch, action: \.killSwitch) {
            KillSwitchQuickSettingFeature()
        }
        Scope(state: \.portForwarding, action: \.portForwarding) {
            PortForwardingQuickSettingFeature()
        }

        Reduce { state, action in
            switch action {
            case let .secureCore(.delegate(.tapped(type))),
                 let .netShield(.delegate(.tapped(type))),
                 let .killSwitch(.delegate(.tapped(type))),
                 let .portForwarding(.delegate(.tapped(type))):
                return .send(.buttonTapped(type))

            case .secureCore, .netShield, .killSwitch, .portForwarding:
                return .none

            case .startObserving:
                state.netShield.stats = environment.initialNetShieldStats()
                return .merge(
                    .send(.netShield(.startObserving)),
                    .send(.portForwarding(.startObserving))
                )

            case let .buttonTapped(type):
                if state.activeType == type {
                    state.destination = nil
                    Self.syncSelection(&state)
                    return .none
                }
                let tier = environment.refreshUserTier()
                state.destination = .quickSettingDetail(QuickSettingDetailFeature.State.makeDetailState(type: type, userTier: tier, from: state))
                Self.syncSelection(&state)
                return .none

            case .dismissDetails:
                state.destination = nil
                Self.syncSelection(&state)
                return .none

            case let .destination(.presented(.quickSettingDetail(.delegate(.option(type, option))))):
                return .run { @MainActor send in
                    await withCheckedContinuation { continuation in
                        environment.performOptionSelection(type, option) {
                            continuation.resume()
                        }
                    }
                    send(.dismissDetails)
                }

            case let .destination(.presented(.quickSettingDetail(.delegate(.upgrade(type))))):
                environment.didTapUpgrade(type)
                return .none

            case .destination:
                return .none

            case let .connectionInfoUpdated(info):
                state.netShield.connectionInfo = info
                state.portForwarding.connectionInfo = info
                Self.syncDetailState(&state)
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private static func syncDetailState(_ state: inout State) {
        guard case let .quickSettingDetail(detail) = state.destination else { return }
        state.destination = .quickSettingDetail(QuickSettingDetailFeature.State.makeDetailState(type: detail.type, userTier: detail.userTier, from: state))
    }

    private static func syncSelection(_ state: inout State) {
        state.secureCore.isSelected = state.activeType == .secureCoreDisplay
        state.netShield.isSelected = state.activeType == .netShieldDisplay
        state.killSwitch.isSelected = state.activeType == .killSwitchDisplay
        state.portForwarding.isSelected = state.activeType == .portForwardingDisplay
    }
}

struct QuickSettingOptionRow: Identifiable {
    let id: QuickSettingOptionID
    let title: String
    let icon: Image
    let isActive: Bool
    let requiresUpdate: Bool
}

enum QuickSettingOptionID: Equatable, Hashable {
    case secureCoreOff
    case secureCoreOn
    case netShield(NetShieldType)
    case killSwitchOff
    case killSwitchOn
    case portForwardingOff
    case portForwardingOn
}

extension QuickSettingsFeature.Destination.State: Equatable {}
