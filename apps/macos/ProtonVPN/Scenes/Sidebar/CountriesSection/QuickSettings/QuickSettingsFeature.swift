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
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Modals
import NetShield
import PaymentsShared
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
        var killSwitchEnabled: Bool
        var portForwardingEnabled: Bool
        var netShieldStatsEnabled: Bool
        var netShieldStats: NetShieldModel
        var connectionInfo: ConnectionInfo
        var visibleQuickSettingTypes: [QuickSettingType]
        /// Per-account NetShield feature settings (from `VpnCredentials.netshield`). Drives
        /// per-level visibility for B2B accounts — levels gated off here are hidden entirely, not
        /// greyed out. Ignored for B2C accounts (where the server may report all-false even for
        /// users who have paid access via the regular tier).
        var netshieldSettings: NetShieldFeatureSettings?
        /// Whether the user's account is a Business plan. Per-account `netshieldSettings` are
        /// authoritative only when this is `true`; for B2C accounts (free or paid) we keep the full
        /// level list visible and rely on tier-based upsell affordances for free users.
        var isBusinessAccount: Bool

        @SharedReader(.userTier) var userTier: Int?

        var selectedTitle: String { type.title }
        var selectedDescription: String { type.description }
        var selectedNote: String? { type.note }

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
                        requiresUpdate: userTier?.isFreeTier ?? true
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
                        requiresUpdate: userTier?.isFreeTier == true
                    ),
                ]
            }
        }

        /// NetShield options, filtered for visibility:
        /// - Globally-disabled levels (currently `.level3` when the kill-switch flag is off) are
        ///   always hidden, regardless of tier or business status — there's no upsell for a feature
        ///   that doesn't exist yet.
        /// - For B2B accounts, per-account `netshieldSettings` further hide levels the plan doesn't
        ///   include.
        /// - For B2C accounts (free or paid), the full level list stays visible. Free users see
        ///   paid levels with the existing upsell affordance via `requiresUpdate`.
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
                        requiresUpdate: row.level != .off && userTier?.isFreeTier == true
                    )
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

        static func makeDetailState(type: QuickSettingType, from state: QuickSettingsFeature.State) -> QuickSettingDetailFeature.State {
            @Dependency(\.credentialsProvider) var credentialsProvider
            return QuickSettingDetailFeature.State(
                type: type,
                secureCoreEnabled: state.secureCore.isEnabled,
                netShieldType: state.netShield.type,
                killSwitchEnabled: state.killSwitch.isEnabled,
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
        case upsell(UpsellSheetFeature)
        case discourageSecureCoreView(DiscourageSecureCoreFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        @Presents var alert: AlertState<Action.Alert>?

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

        var isSearchDisabled: Bool { activeType != nil }

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
        case refreshConnectionInfo
        case vpnConnectionStatusUpdated(isConnected: Bool, supportsP2P: Bool)
        case buttonTapped(QuickSettingType)
        case dismissDetails
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Equatable {
            case confirmKillSwitchOn
            case cancelKillSwitchOn
            case confirmDisableHermesAndSetNetShield(NetShieldType)
        }
    }

    struct Environment {
        var performOptionSelection: @Sendable (QuickSettingType, QuickSettingOptionID, @escaping @Sendable () -> Void) -> Void
        var initialNetShieldStats: @Sendable () -> NetShieldModel
    }

    @SharedReader(.discourageSecureCore) private var discourageSecureCore: Bool

    @Dependency(\.sessionService) var sessionService
    @Dependency(\.linkOpener) var linkOpener
    @Dependency(\.propertiesManager) var propertiesManager
    @Dependency(\.appFeaturePropertyProvider) var appFeaturePropertyProvider
    @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
    @Dependency(\.natPortMappingService) var natPortMappingService
    @Dependency(\.vpnConnectionStatusPublisher) var vpnConnectionStatusPublisher
    @Dependency(\.hermesClient) var hermesClient

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
                // Keep currently presented detail view in sync with live quick-setting state changes.
                Self.syncDetailState(&state)
                return .none

            case .startObserving:
                state.netShield.stats = environment.initialNetShieldStats()
                return .merge(
                    .send(.netShield(.startObserving)),
                    .send(.portForwarding(.startObserving)),
                    .send(.refreshConnectionInfo),
                    .run { send in
                        for await status in vpnConnectionStatusPublisher() {
                            await send(.vpnConnectionStatusUpdated(
                                isConnected: status.is(\.connected),
                                supportsP2P: status.server?.logical.feature.contains(.p2p) == true
                            ))
                        }
                    },
                    .run { send in
                        for await _ in portForwardingPropertyProvider.portForwardingStream() {
                            await send(.refreshConnectionInfo)
                        }
                    },
                    .run { send in
                        for await _ in natPortMappingService.portMappingStream.values {
                            await send(.refreshConnectionInfo)
                        }
                    }
                )

            case let .vpnConnectionStatusUpdated(isConnected, supportsP2P):
                state.portForwarding.connectionInfo = .portForwardingStatus(
                    enabled: state.portForwarding.isEnabled,
                    supportsP2P: supportsP2P,
                    isConnected: isConnected
                )
                state.netShield.connectionInfo = state.portForwarding.connectionInfo
                Self.syncDetailState(&state)
                return .send(.refreshConnectionInfo)

            case .refreshConnectionInfo:
                let isConnected = state.portForwarding.connectionInfo.isConnected
                let supportsP2P: Bool = switch state.portForwarding.connectionInfo {
                case let .portForwardingStatus(_, supportsP2P, _):
                    supportsP2P
                case .pfError:
                    false
                }

                let portForwardingEnabled = portForwardingPropertyProvider.getPortForwarding() ?? false
                let info: ConnectionInfo = if case .failure = natPortMappingService.portMappingStream.value {
                    .pfError(isConnected: isConnected)
                } else {
                    .portForwardingStatus(
                        enabled: portForwardingEnabled,
                        supportsP2P: supportsP2P,
                        isConnected: isConnected
                    )
                }

                state.netShield.connectionInfo = info
                state.portForwarding.connectionInfo = info
                Self.syncDetailState(&state)
                return .none

            case let .buttonTapped(type):
                if state.activeType == type {
                    state.destination = nil
                    Self.syncSelection(&state)
                    return .none
                }
                state.destination = .quickSettingDetail(QuickSettingDetailFeature.State.makeDetailState(type: type, from: state))
                Self.syncSelection(&state)
                return .none

            case .dismissDetails:
                guard state.activeType != nil else { return .none }
                state.destination = nil
                Self.syncSelection(&state)
                return .none

            case let .destination(.presented(.quickSettingDetail(.delegate(.option(type, option))))):
                if type == .killSwitchDisplay, option == .killSwitchOn, Self.requiresKillSwitchConflictConfirmation(appFeaturePropertyProvider: appFeaturePropertyProvider) {
                    state.alert = Self.killSwitchConflictAlert
                    return .none
                }
                if case let .netShield(level) = option, level != .off, hermesClient.isEnabled().wrappedValue {
                    state.alert = Self.hermesConflictAlert(level: level)
                    return .none
                }
                if Self.optionRequiresUpsell(type: type, option: option),
                   let modalType = Self.upsellModalType(for: type) {
                    state.destination = .upsell(.init(modalType: modalType))
                    Self.syncSelection(&state)
                    return .none
                }
                if type == .secureCoreDisplay, option == .secureCoreOn, discourageSecureCore {
                    state.destination = .discourageSecureCoreView(.init())
                    Self.syncSelection(&state)
                    return .none
                }
                return .run { @MainActor send in
                    await withCheckedContinuation { continuation in
                        environment.performOptionSelection(type, option) {
                            continuation.resume()
                        }
                    }
                    send(.dismissDetails)
                }

            case let .destination(.presented(.quickSettingDetail(.delegate(.upgrade(type))))):
                guard let modalType = Self.upsellModalType(for: type) else { return .none }
                state.destination = .upsell(.init(modalType: modalType))
                Self.syncSelection(&state)
                return .none

            case .destination(.presented(.upsell(.upgradeTapped))):
                state.destination = nil
                return .run { _ in
                    guard let url = await sessionService.getPlanSession(mode: .upgrade) else {
                        return
                    }
                    await MainActor.run {
                        linkOpener.open(url)
                    }
                }

            case .destination(.presented(.upsell(.continueTapped))):
                state.destination = nil
                return .none

            case .destination(.presented(.discourageSecureCoreView(.delegate(.activateTapped)))):
                state.destination = nil
                return .run { @MainActor send in
                    await withCheckedContinuation { continuation in
                        environment.performOptionSelection(.secureCoreDisplay, .secureCoreOn) {
                            continuation.resume()
                        }
                    }
                    send(.dismissDetails)
                }

            case .destination(.dismiss):
                return .none

            case .destination:
                return .none

            case .alert(.presented(.cancelKillSwitchOn)):
                return .send(.dismissDetails)

            case .alert(.presented(.confirmKillSwitchOn)):
                return .run { @MainActor send in
                    await withCheckedContinuation { continuation in
                        environment.performOptionSelection(.killSwitchDisplay, .killSwitchOn) {
                            continuation.resume()
                        }
                    }
                    send(.dismissDetails)
                }

            case let .alert(.presented(.confirmDisableHermesAndSetNetShield(level))):
                hermesClient.setIsEnabled(false)
                return .run { @MainActor send in
                    await withCheckedContinuation { continuation in
                        environment.performOptionSelection(.netShieldDisplay, .netShield(level)) {
                            continuation.resume()
                        }
                    }
                    send(.dismissDetails)
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    private static func syncDetailState(_ state: inout State) {
        guard case let .quickSettingDetail(detail) = state.destination else { return }
        state.destination =
            .quickSettingDetail(
                QuickSettingDetailFeature.State
                    .makeDetailState(type: detail.type, from: state)
            )
    }

    private static func syncSelection(_ state: inout State) {
        state.secureCore.isSelected = state.activeType == .secureCoreDisplay
        state.netShield.isSelected = state.activeType == .netShieldDisplay
        state.killSwitch.isSelected = state.activeType == .killSwitchDisplay
        state.portForwarding.isSelected = state.activeType == .portForwardingDisplay
    }

    private static func upsellModalType(for type: QuickSettingType) -> UpsellModalType? {
        switch type {
        case .secureCoreDisplay:
            .secureCore
        case .netShieldDisplay:
            .netShield
        case .killSwitchDisplay:
            nil
        case .portForwardingDisplay:
            .portForwarding
        }
    }

    private static func optionRequiresUpsell(type: QuickSettingType, option: QuickSettingOptionID) -> Bool {
        @SharedReader(.userTier) var userTier: Int?
        switch (type, option) {
        case (.secureCoreDisplay, .secureCoreOn):
            return userTier?.isFreeTier ?? true
        case let (.netShieldDisplay, .netShield(level)):
            return level.isUserTierTooLow(userTier ?? Int.freeTier)
        case (.portForwardingDisplay, .portForwardingOn):
            return userTier?.isFreeTier ?? true
        default:
            return false
        }
    }

    private static func requiresKillSwitchConflictConfirmation(
        appFeaturePropertyProvider: AppFeaturePropertyProvider
    ) -> Bool {
        @Shared(.plutoniumFeature) var plutonium: PlutoniumFeatureToggle
        let excludeLocalNetworksIsOff = appFeaturePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .off
        switch (excludeLocalNetworksIsOff, plutonium) {
        case (true, .disabled):
            return false
        default:
            return true
        }
    }

    static var killSwitchConflictAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.turnKsOnTitle) },
            actions: {
                ButtonState(
                    action: .send(.confirmKillSwitchOn),
                    label: { TextState(Localizable.continue) }
                )
                ButtonState(
                    role: .cancel,
                    action: .send(.cancelKillSwitchOn),
                    label: { TextState(Localizable.cancel) }
                )
            },
            message: { TextState(Localizable.turnKsOnDescriptionMacosStConflict + "\n" + Localizable.turnKsOnDescriptionMacosLanConflict) }
        )
    }

    static func hermesConflictAlert(level: NetShieldType) -> AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.hermesConflictNetshieldOnTitle) },
            actions: {
                ButtonState(
                    action: .send(.confirmDisableHermesAndSetNetShield(level)),
                    label: { TextState(Localizable.continue) }
                )
                ButtonState(
                    role: .cancel,
                    label: { TextState(Localizable.notNow) }
                )
            },
            message: { TextState(Localizable.hermesConflictNetshieldOnDescription) }
        )
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
