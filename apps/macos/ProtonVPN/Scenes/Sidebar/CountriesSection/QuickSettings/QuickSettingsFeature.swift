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
import Localization
import Modals
import NetShield
import PaymentsShared
import Settings
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
        case connectionStateUpdated(isConnected: Bool, supportsP2P: Bool)
        case buttonTapped(QuickSettingType)
        case dismissDetails
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Equatable {
            /// Confirmed a mode-up Kill Switch transition (Off→Standard, Off→Advanced, Standard→Advanced).
            /// The target mode is captured so the apply path doesn't re-derive it.
            case confirmKillSwitchMode(KillSwitchMode)
            case cancelKillSwitchMode
            case confirmDisableHermesAndSetNetShield(NetShieldType)
            /// Confirmed mid-session Secure Core toggle. `turningOn` is captured at the moment
            /// the alert is presented so the apply path doesn't have to re-derive direction
            /// from the (potentially mutated) `secureCoreToggle` shared value.
            case confirmSecureCoreToggle(turningOn: Bool)
        }
    }

    @SharedReader(.discourageSecureCore) private var discourageSecureCore: Bool
    @SharedReader(.connectionState) private var connectionState: ConnectionState
    @Shared(.secureCoreToggle) private var secureCoreToggle: Bool
    @Shared(.killSwitchMode) private var killSwitchMode: KillSwitchMode
    @Shared(.plutoniumFeature) var plutonium: PlutoniumFeatureToggle

    @Dependency(\.sessionService) var sessionService
    @Dependency(\.linkOpener) var linkOpener
    @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
    @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
    @Dependency(\.natPortMappingService) var natPortMappingService
    @Dependency(\.hermesClient) var hermesClient
    @Dependency(\.connectionCommandClient) var connectionCommandClient
    @Dependency(\.serverRepository) var serverRepository

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

        CombineReducers {
            childSettingsReducer
            observationReducer
            detailNavigationReducer
            alertReducer
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Sub-reducers

private extension QuickSettingsFeature {
    var childSettingsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .secureCore(.delegate(.tapped(type))),
                 let .netShield(.delegate(.tapped(type))),
                 let .killSwitch(.delegate(.tapped(type))),
                 let .portForwarding(.delegate(.tapped(type))):
                return .send(.buttonTapped(type))

            case .secureCore, .netShield, .killSwitch, .portForwarding:
                Self.syncDetailState(&state)
                return .none

            default:
                return .none
            }
        }
    }

    /// Lifecycle: wires the long-lived observation streams (connectionState, port-forwarding
    /// pref, NAT-PMP results) and recomputes the `ConnectionInfo` exposed to the views from
    /// the live property/service values.
    var observationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startObserving:
                state.netShield.stats = .zero(enabled: false)
                return .merge(
                    .send(.netShield(.startObserving)),
                    .send(.portForwarding(.startObserving)),
                    .send(.refreshConnectionInfo),
                    .run { [connectionState = $connectionState] send in
                        for await state in connectionState.publisher.values {
                            await send(.connectionStateUpdated(
                                isConnected: state.is(\.connected),
                                supportsP2P: state.resolvedServer?.logical.feature.contains(.p2p) == true
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

            case let .connectionStateUpdated(isConnected, supportsP2P):
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
                case let .portForwardingStatus(_, supportsP2P, _): supportsP2P
                case .pfError: false
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

            default:
                return .none
            }
        }
    }

    /// Owns the detail-sheet / upsell / discourage-secure-core modal
    var detailNavigationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .buttonTapped(type):
                // Toggle: tapping the active row dismisses, anything else swaps the detail body.
                if state.activeType == type {
                    state.destination = nil
                    Self.syncSelection(&state)
                    return .none
                }
                state.destination = .quickSettingDetail(
                    QuickSettingDetailFeature.State.makeDetailState(type: type, from: state)
                )
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
                // Alerts before applying: Kill Switch mode-up confirmation, NetShield/Hermes
                // conflict alert, paywall upsell, Secure Core discourage modal. Only after all
                // of these pass do we hand off to `applyQuickSettingOptionSelection`.
                if type == .killSwitchDisplay, let targetMode = option.killSwitchMode {
                    // Confirm only on mode-up transitions (increasing protection); downgrades and Off
                    // apply immediately
                    if targetMode.rawValue > killSwitchMode.rawValue {
                        state.alert = Self.killSwitchModeUpAlert(from: killSwitchMode, to: targetMode)
                        return .none
                    }
                    apply(.killSwitch(mode: targetMode))
                    return .send(.dismissDetails)
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

                if type == .secureCoreDisplay {
                    let turningOn = (option == .secureCoreOn)
                    let isConnected = connectionState.isConnected
                    let fallback = fallbackCountryName(turningOn: turningOn)

                    // Unified iOS/macOS matrix.
                    //   switch (turningOn, discourageSecureCore, isConnected) {
                    //   case (true,  true,  true ): discourage screen + reconnect notice
                    //   case (true,  true,  false): discourage screen
                    //   case (true,  false, true ): short alert
                    //   case (false, _,     true ): short alert
                    //   default:                    apply silently
                    //   }

                    switch (turningOn, discourageSecureCore, isConnected) {
                    case (true, true, true):
                        let notice = SecureCoreConnectionSpecResolver.toggleAlertMessage(
                            turningOn: true,
                            fallbackCountryName: fallback
                        )
                        state.destination = .discourageSecureCoreView(.init(reconnectNotice: notice))
                        Self.syncSelection(&state)
                        return .none

                    case (true, true, false):
                        state.destination = .discourageSecureCoreView(.init(reconnectNotice: nil))
                        Self.syncSelection(&state)
                        return .none

                    case (true, false, true), (false, _, true):
                        state.alert = Self.secureCoreToggleAlert(turningOn: turningOn, fallbackCountryName: fallback)
                        Self.syncSelection(&state)
                        return .none

                    default:
                        break // apply silently
                    }
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
                    guard let url = await sessionService.getPlanSession(mode: .upgrade) else { return }
                    await MainActor.run { linkOpener.open(url) }
                }

            case .destination(.presented(.upsell(.skipActionTapped))):
                state.destination = nil
                return .none

            case .destination(.presented(.discourageSecureCoreView(.delegate(.activateTapped)))):
                state.destination = nil
                applyQuickSettingOptionSelection(type: .secureCoreDisplay, option: .secureCoreOn)
                return .send(.dismissDetails)

            case .destination:
                return .none

            default:
                return .none
            }
        }
    }

    /// Handles confirm/cancel from the conflict alerts surfaced by `detailNavigationReducer`.
    var alertReducer: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .alert(.presented(.cancelKillSwitchMode)):
                return .send(.dismissDetails)

            case let .alert(.presented(.confirmKillSwitchMode(mode))):
                apply(.killSwitch(mode: mode))
                return .send(.dismissDetails)

            case let .alert(.presented(.confirmDisableHermesAndSetNetShield(level))):
                hermesClient.setIsEnabled(false)
                applyQuickSettingOptionSelection(type: .netShieldDisplay, option: .netShield(level))
                return .send(.dismissDetails)

            case let .alert(.presented(.confirmSecureCoreToggle(turningOn))):
                applyQuickSettingOptionSelection(
                    type: .secureCoreDisplay,
                    option: turningOn ? .secureCoreOn : .secureCoreOff
                )
                return .send(.dismissDetails)

            case .alert:
                return .none

            default:
                return .none
            }
        }
    }
}

// MARK: - Detail sheet sync helpers

private extension QuickSettingsFeature {
    /// Rebuilds the presented detail sheet from current state. Called whenever any input
    /// that feeds into `QuickSettingDetailFeature.State.makeDetailState` may have changed.
    static func syncDetailState(_ state: inout State) {
        guard case let .quickSettingDetail(detail) = state.destination else { return }
        state.destination = .quickSettingDetail(
            QuickSettingDetailFeature.State.makeDetailState(type: detail.type, from: state)
        )
    }

    /// Mirrors `state.activeType` to each child's `isSelected` so the tab-bar highlight stays
    /// consistent without each child observing the parent's destination.
    static func syncSelection(_ state: inout State) {
        state.secureCore.isSelected = state.activeType == .secureCoreDisplay
        state.netShield.isSelected = state.activeType == .netShieldDisplay
        state.killSwitch.isSelected = state.activeType == .killSwitchDisplay
        state.portForwarding.isSelected = state.activeType == .portForwardingDisplay
    }
}

// MARK: - Quick-setting option application

private extension QuickSettingsFeature {
    /// Boundary between the loosely-typed `(QuickSettingType, QuickSettingOptionID)` pair
    /// (which the detail-sheet delegate produces) and the strongly-typed apply path. The pair
    /// can in principle hold inconsistent combinations like `(.killSwitchDisplay, .netShield(...))`;
    /// validating into this enum once means `apply(_:)` is exhaustive and the type system
    /// rejects new mismatched cases at compile time.
    enum QuickSettingChange: Equatable {
        case secureCore(enabled: Bool)
        case killSwitch(mode: KillSwitchMode)
        case netShield(NetShieldType)
        case portForwarding(enabled: Bool)

        init?(type: QuickSettingType, option: QuickSettingOptionID) {
            switch (type, option) {
            case (.secureCoreDisplay, .secureCoreOff): self = .secureCore(enabled: false)
            case (.secureCoreDisplay, .secureCoreOn): self = .secureCore(enabled: true)
            case (.killSwitchDisplay, .killSwitchOff): self = .killSwitch(mode: .off)
            case (.killSwitchDisplay, .killSwitchStandard): self = .killSwitch(mode: .standard)
            case (.killSwitchDisplay, .killSwitchAdvanced): self = .killSwitch(mode: .advanced)
            case let (.netShieldDisplay, .netShield(level)): self = .netShield(level)
            case (.portForwardingDisplay, .portForwardingOff): self = .portForwarding(enabled: false)
            case (.portForwardingDisplay, .portForwardingOn): self = .portForwarding(enabled: true)
            default: return nil
            }
        }
    }

    func applyQuickSettingOptionSelection(
        type: QuickSettingType,
        option: QuickSettingOptionID
    ) {
        guard let change = QuickSettingChange(type: type, option: option) else {
            assertionFailure("Mismatched quick setting type/option pair: \(type), \(option)")
            SentryHelper.shared?.log(message: "Mismatched quick setting type/option pair: \(type), \(option)")
            return
        }
        apply(change)
    }

    /// Persists the user's choice for the selected quick setting and either applies the change
    /// live via local agent or triggers a reconnect, depending on the protocol/connection state.
    func apply(_ change: QuickSettingChange) {
        switch change {
        case let .secureCore(enabled):
            $secureCoreToggle.withLock { $0 = enabled }
            quickSettingsDisplayReconnectionFeedback()

        case let .killSwitch(mode):
            // KS is mutually exclusive with both ExcludeLocalNetworks (LAN) and Plutonium (Split
            // Tunneling). When enabling any protected mode, force them off; the mode-up confirmation
            // already informed the user before we got here.
            $killSwitchMode.withLock { $0 = mode }
            if mode.isProtected {
                setFeatureValue(ExcludeLocalNetworks.off)
                $plutonium.withLock { $0 = .disabled(plutonium.mode) }
            }
            // The connection effect is handled by SidebarFeature by observing `killSwitchMode`

        case let .netShield(level):
            quickSettingsChangeNetShieldLevel(level)

        case let .portForwarding(enabled):
            quickSettingsChangePortForwarding(enabled)
        }
    }

    /// Fires a passive reconnect when a Secure Core toggle change happens mid-connection.
    /// No-op if not connected — the new toggle value will be picked up on the next connect.
    func quickSettingsDisplayReconnectionFeedback() {
        guard connectionState.isConnected else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        @SharedReader(.userTier) var userTier: VpnTier?
        let isFree = userTier.isFree
        let connectedCountryCode = connectionState.resolvedServer?.logical.exitCountryCode
        let canReuseCurrentExitCountry: Bool = if let connectedCountryCode {
            serverRepository.hasServer(
                secureCore: secureCoreToggle,
                exitCountryCode: connectedCountryCode
            )
        } else {
            false
        }
        let resolvedExit = canReuseCurrentExitCountry ? connectedCountryCode : nil
        let spec = SecureCoreConnectionSpecResolver.toggleReconnectSpec(
            secureCoreEnabled: secureCoreToggle,
            exitCountryCode: resolvedExit,
            isFree: isFree
        )
        let intent = SecureCoreConnectionSpecResolver.reconnectTrigger(
            connectedExitCountryCode: resolvedExit,
            isFree: isFree
        )
        let connectionProtocol = connectionState.resolvedVpnProtocol.map(ConnectionProtocol.vpnProtocol)
        connectionCommandClient.send(.connect(spec, connectionProtocol, intent))
    }

    func quickSettingsChangeNetShieldLevel(_ level: NetShieldType) {
        netShieldPropertyProvider.setNetShieldType(level)
        switch VpnFeatureChangeState(connectionState: connectionState) {
        case .withConnectionUpdate:
            connectionCommandClient.send(.applySettings([.agent(.netShield(level))]))
        case .withReconnect:
            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
            connectionCommandClient.send(.retry)
        case .immediate:
            // we're in disconnected state, and netShield was set before switch
            break
        }
    }

    func quickSettingsChangePortForwarding(_ isEnabled: Bool) {
        portForwardingPropertyProvider.setPortForwarding(isEnabled)
        switch VpnFeatureChangeState(connectionState: connectionState) {
        case .withConnectionUpdate:
            log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
            connectionCommandClient.send(.applySettings([.agent(.portForwarding(isEnabled))]))
        case .withReconnect:
            guard isConnectionActive else { return }
            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
            if let activeVpnProtocol = connectionState.resolvedVpnProtocol {
                connectionCommandClient.send(.reconnect(.vpnProtocol(activeVpnProtocol)))
            } else {
                connectionCommandClient.send(.retry)
            }
        case .immediate:
            // we're in disconnected state, and portForwarding was set before switch
            break
        }
    }

    var isConnectionActive: Bool {
        switch connectionState {
        case .disconnected, .resolving, .killSwitchActive: false
        case .connecting, .connected, .disconnecting: true
        }
    }
}

// MARK: - Upsell / conflict helpers

extension QuickSettingsFeature {
    static func upsellModalType(for type: QuickSettingType) -> UpsellModalType? {
        switch type {
        case .secureCoreDisplay: .secureCore
        case .netShieldDisplay: .netShield
        case .killSwitchDisplay: nil
        case .portForwardingDisplay: .portForwarding
        }
    }

    /// Whether tapping an option in the detail sheet should be intercepted by an upsell.
    /// Free users hit the paywall for Secure Core, Port Forwarding, and any NetShield level
    /// above their entitlement.
    static func optionRequiresUpsell(type: QuickSettingType, option: QuickSettingOptionID) -> Bool {
        @SharedReader(.userTier) var userTier: VpnTier?
        switch (type, option) {
        case (.secureCoreDisplay, .secureCoreOn):
            return userTier.isFree
        case let (.netShieldDisplay, .netShield(level)):
            return level.isUserTierTooLow(userTier ?? .free)
        case (.portForwardingDisplay, .portForwardingOn):
            return userTier.isFree
        default:
            return false
        }
    }

    /// Mode-up confirmation for enabling/increasing Kill Switch protection
    static func killSwitchModeUpAlert(from current: KillSwitchMode, to mode: KillSwitchMode) -> AlertState<Action.Alert> {
        let title: String
        let bullets: [String]
        let confirmTitle: String
        switch mode {
        case .standard:
            // Off → Standard
            title = Localizable.killSwitchEnableStandardTitle
            bullets = [
                Localizable.killSwitchBulletSplitTunneling,
                Localizable.killSwitchBulletNoLan,
                Localizable.killSwitchBulletDeferred,
            ]
            confirmTitle = Localizable.killSwitchConfirmEnable
        case .advanced where current == .standard:
            // Standard → Advanced
            title = Localizable.killSwitchSwitchAdvancedTitle
            bullets = [
                Localizable.killSwitchBulletAdvancedPersists,
                Localizable.killSwitchBulletAdvancedRecover,
                Localizable.killSwitchBulletDeferred,
            ]
            confirmTitle = Localizable.killSwitchConfirmSwitch
        case .advanced:
            // Off → Advanced
            title = Localizable.killSwitchEnableAdvancedTitle
            bullets = [
                Localizable.killSwitchBulletSplitTunneling,
                Localizable.killSwitchBulletNoLan,
                Localizable.killSwitchBulletAdvancedPersists,
                Localizable.killSwitchBulletDeferred,
            ]
            confirmTitle = Localizable.killSwitchConfirmEnable
        case .off:
            // Not a mode-up; never reached (downgrade/Off applies without a dialog).
            title = ""
            bullets = []
            confirmTitle = Localizable.killSwitchConfirmEnable
        }
        let message = bullets.map { "•  \($0)" }.joined(separator: "\n")
        return AlertState(
            title: { TextState(title) },
            actions: {
                ButtonState(
                    action: .send(.confirmKillSwitchMode(mode)),
                    label: { TextState(confirmTitle) }
                )
                ButtonState(
                    role: .cancel,
                    action: .send(.cancelKillSwitchMode),
                    label: { TextState(Localizable.cancel) }
                )
            },
            message: { TextState(message) }
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

    /// A confirmation alert warning that toggling Secure Core mid-session
    /// will trigger a reconnect.
    /// If no Secure Core server is available in the currently connected country, the
    /// message falls back to the generic "global fastest" copy instead of naming a country.
    static func secureCoreToggleAlert(turningOn: Bool, fallbackCountryName: String?) -> AlertState<Action.Alert> {
        let message = SecureCoreConnectionSpecResolver.toggleAlertMessage(
            turningOn: turningOn,
            fallbackCountryName: fallbackCountryName
        )
        return AlertState(
            title: { TextState(Localizable.warning) },
            actions: {
                ButtonState(
                    action: .send(.confirmSecureCoreToggle(turningOn: turningOn)),
                    label: { TextState(Localizable.continue) }
                )
                ButtonState(
                    role: .cancel,
                    label: { TextState(Localizable.cancel) }
                )
            },
            message: { TextState(message) }
        )
    }
}

private extension QuickSettingsFeature {
    /// Localized name of the connected exit country to show in the alert/discourage view when
    /// no Secure Core server exits via it. Nil when turning off, disconnected, or an SC
    /// server is available.
    func fallbackCountryName(turningOn: Bool) -> String? {
        guard turningOn, let cc = connectionState.resolvedServer?.logical.exitCountryCode,
              !serverRepository.hasServer(secureCore: true, exitCountryCode: cc) else { return nil }
        return LocalizationUtility.default.countryName(forCode: cc) ?? cc
    }
}

enum QuickSettingOptionID: Equatable, Hashable {
    case secureCoreOff
    case secureCoreOn
    case netShield(NetShieldType)
    case killSwitchOff
    case killSwitchStandard
    case killSwitchAdvanced
    case portForwardingOff
    case portForwardingOn

    /// The Kill Switch mode this option represents, or `nil` for non-KS options.
    var killSwitchMode: KillSwitchMode? {
        switch self {
        case .killSwitchOff: .off
        case .killSwitchStandard: .standard
        case .killSwitchAdvanced: .advanced
        default: nil
        }
    }
}

extension QuickSettingsFeature.Destination.State: Equatable {}
