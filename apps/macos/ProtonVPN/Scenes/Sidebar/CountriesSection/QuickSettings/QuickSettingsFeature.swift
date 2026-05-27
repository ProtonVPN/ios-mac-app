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
import Connection
import ConnectionInventory
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

        var isSearchDisabled: Bool {
            activeType != nil
        }

        var netShieldBadgeVisible: Bool {
            netShield.badgeVisible
        }

        var netShieldBadgeModel: NetShieldModel {
            netShield.badgeModel
        }

        var netShieldBadgeText: String {
            netShield.badgeText
        }
    }

    enum Action {
        case secureCore(SecureCoreQuickSettingFeature.Action)
        case netShield(NetShieldQuickSettingFeature.Action)
        case killSwitch(KillSwitchQuickSettingFeature.Action)
        case portForwarding(PortForwardingQuickSettingFeature.Action)
        case presentUpsell(UpsellModalType)

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

    @SharedReader(.discourageSecureCore) private var discourageSecureCore: Bool
    @Shared(.vpnConnectionStatus) private var vpnConnectionStatus: VPNConnectionStatus
    @Shared(.connectionState) private var connectionState: ConnectionState
    @Shared(.secureCoreToggle) private var secureCoreToggle: Bool

    @Dependency(\.sessionService) var sessionService
    @Dependency(\.linkOpener) var linkOpener
    @Dependency(\.propertiesManager) var propertiesManager
    @Dependency(\.appFeaturePropertyProvider) var appFeaturePropertyProvider
    @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
    @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
    @Dependency(\.natPortMappingService) var natPortMappingService
    @Dependency(\.hermesClient) var hermesClient
    @Dependency(\.connectionCommandClient) var connectionCommandClient

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
                state.netShield.stats = .zero(enabled: false)
                return .merge(
                    .send(.netShield(.startObserving)),
                    .send(.portForwarding(.startObserving)),
                    .send(.refreshConnectionInfo),
                    .run { [vpnConnectionStatus = $vpnConnectionStatus] send in
                        for await status in vpnConnectionStatus.publisher.values {
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

            case let .presentUpsell(modalType):
                state.destination = .upsell(.init(modalType: modalType))
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
                applyQuickSettingOptionSelection(type: type, option: option)
                return .send(.dismissDetails)

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

            case .destination(.presented(.upsell(.optionalActionTapped))):
                state.destination = nil
                return .none

            case .destination(.presented(.discourageSecureCoreView(.delegate(.activateTapped)))):
                state.destination = nil
                applyQuickSettingOptionSelection(type: .secureCoreDisplay, option: .secureCoreOn)
                return .send(.dismissDetails)

            case .destination(.dismiss):
                return .none

            case .destination:
                return .none

            case .alert(.presented(.cancelKillSwitchOn)):
                return .send(.dismissDetails)

            case .alert(.presented(.confirmKillSwitchOn)):
                applyQuickSettingOptionSelection(type: .killSwitchDisplay, option: .killSwitchOn)
                return .send(.dismissDetails)

            case let .alert(.presented(.confirmDisableHermesAndSetNetShield(level))):
                hermesClient.setIsEnabled(false)
                applyQuickSettingOptionSelection(type: .netShieldDisplay, option: .netShield(level))
                return .send(.dismissDetails)

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

    private func applyQuickSettingOptionSelection(
        type: QuickSettingType,
        option: QuickSettingOptionID
    ) {
        switch (type, option) {
        case (.secureCoreDisplay, .secureCoreOff):
            $secureCoreToggle.withLock { $0 = false }
            quickSettingsDisplayReconnectionFeedback()

        case (.secureCoreDisplay, .secureCoreOn):
            $secureCoreToggle.withLock { $0 = true }
            quickSettingsDisplayReconnectionFeedback()

        case (.killSwitchDisplay, .killSwitchOff):
            propertiesManager.killSwitch = false
            if connectionState.isConnected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                connectionCommandClient.send(.retry)
            }

        case (.killSwitchDisplay, .killSwitchOn):
            @Shared(.plutoniumFeature) var plutonium: PlutoniumFeatureToggle
            propertiesManager.killSwitch = true
            appFeaturePropertyProvider.setValue(ExcludeLocalNetworks.off)
            $plutonium.withLock { $0 = .disabled(plutonium.mode) }
            if connectionState.isConnected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                connectionCommandClient.send(.retry)
            }

        case let (.netShieldDisplay, .netShield(level)):
            quickSettingsChangeNetShieldLevel(level)

        case (.portForwardingDisplay, .portForwardingOff):
            quickSettingsChangePortForwarding(false)

        case (.portForwardingDisplay, .portForwardingOn):
            quickSettingsChangePortForwarding(true)

        default:
            break
        }
    }

    private func quickSettingsDisplayReconnectionFeedback() {
        guard connectionState.isConnected else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        @SharedReader(.userTier) var userTier: Int?
        let isFreeTier = userTier?.isFreeTier ?? true
        let connectedCountryCode = vpnConnectionStatus.mergedServer(using: connectionState)?.logical.exitCountryCode
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: secureCoreToggle,
            connectedExitCountryCode: connectedCountryCode,
            isFreeTier: isFreeTier
        )
        let intent = SecureCoreConnectionSpecResolver.reconnectTrigger(
            connectedExitCountryCode: connectedCountryCode,
            isFreeTier: isFreeTier
        )
        connectionCommandClient.send(.connect(spec, nil, intent))
    }

    private func quickSettingsChangeNetShieldLevel(_ level: NetShieldType) {
        switch VpnFeatureChangeState(connectionState: connectionState, vpnConnectionStatus: vpnConnectionStatus) {
        case .withConnectionUpdate:
            netShieldPropertyProvider.setNetShieldType(level)
            let features: Set<ConnectionFeatureChange.AgentFeature> = [.netShield(level)]
            connectionCommandClient.send(.applySettings(features))
        case .withReconnect:
            netShieldPropertyProvider.setNetShieldType(level)
            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
            connectionCommandClient.send(.retry)
        case .immediate:
            netShieldPropertyProvider.setNetShieldType(level)
        }
    }

    private func quickSettingsChangePortForwarding(_ isEnabled: Bool) {
        portForwardingPropertyProvider.setPortForwarding(isEnabled)
        switch VpnFeatureChangeState(connectionState: connectionState, vpnConnectionStatus: vpnConnectionStatus) {
        case .withConnectionUpdate:
            log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
            let features: Set<ConnectionFeatureChange.AgentFeature> = [.portForwarding(isEnabled)]
            connectionCommandClient.send(.applySettings(features))
        case .withReconnect:
            if isConnectionActive {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                if let activeVpnProtocol = vpnConnectionStatus.mergedVpnProtocol(using: connectionState) {
                    connectionCommandClient.send(.reconnect(.vpnProtocol(activeVpnProtocol)))
                } else {
                    connectionCommandClient.send(.retry)
                }
            }
        case .immediate:
            break
        }
    }

    private var isConnectionActive: Bool {
        switch connectionState {
        case .disconnected, .resolving:
            false
        case .connecting, .connected, .disconnecting:
            true
        }
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
