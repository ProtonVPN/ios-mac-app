//
//  Created on 29/07/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Connection
import CoreConnection
import Dependencies
import Domain
import ExtensionSync
import Foundation
import Sharing
import Strings
import VPNAppCore

/// Requests that belong to Home's tree, the payment upsells for resolution failures and the FIDO notice sheet, leave
/// through `Delegate` for the composing shell to route. Everything else is connection machinery that gets handled here
/// and passed onto the ConnectionFeature.
@Reducer
public struct ConnectionCommandsFeature {
    @Dependency(\.serverChangeAuthorizer) private var authorizer
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.pendingDisconnectCompletions) private var pendingDisconnectCompletions
    @Dependency(\.networkInterfacePropertiesProvider) private var networkInterfacePropertiesProvider

    @Shared(.killSwitchMode) private var killSwitchMode: KillSwitchMode

    @ObservableState
    public struct State: Equatable {
        public var connection: ConnectionFeature.State

        @SharedReader(.connectionState) public var connectionState: ConnectionState

        @Presents public var alert: AlertState<Action.Alert>?

        public init() {
            self.connection = .initialState
        }
    }

    /// Captures the parameters of a `.connect` command paused while we await user input on an intercept alert.
    public struct PendingConnect: Equatable, Sendable {
        public let spec: ConnectionSpec
        public let connectionProtocol: ConnectionProtocol?
        public let trigger: UserInitiatedVPNChange.VPNTrigger?
    }

    /// Disconnects that are part of a larger flow the user already confirmed (or never initiated directly), which must
    /// not be interrupted by the Advanced kill switch confirmation.
    private static let advancedKillSwitchConfirmationExemptTriggers: Set<UserInitiatedVPNChange.VPNTrigger> = [
        .auto, .exit, .fidoAuthentication, .signout, .widget,
    ]

    private enum CancelID {
        case connectionCommands
        case connectionConnectCommandEffect
        case killSwitchMode
    }

    public enum Action {
        case onStart

        /// Forwarded from the `ConnectionCommandClient` stream. Single chokepoint that translates a `ConnectionCommand`
        /// into `ConnectionFeature.input(...)`.
        case commandReceived(ConnectionCommand)

        case killSwitchModeChanged(KillSwitchMode)
        case connection(ConnectionFeature.Action)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        @CasePathable
        public enum Alert: Equatable {
            /// User chose "Enable Kill Switch" on the bad-LAN alert. We flip the kill switch (which suppresses the
            /// bad-LAN intercept on the re-issued connect) and retry.
            case enableKillSwitchAndConnect(PendingConnect)
            /// User chose "Continue" on the bad-LAN alert. We retry connect bypassing intercepts.
            case connectAnywayDespiteBadLAN(PendingConnect)
            /// User confirmed disconnecting while Advanced kill switch is active. The original trigger is re-posted
            /// before the disconnect is issued.
            case confirmDisconnectWithAdvancedKillSwitch(UserInitiatedVPNChange.VPNTrigger)
        }

        public enum Delegate {
            case connectionFailed(ConnectionError)
            case intentResolutionFailed(ConnectionIntentResolutionError)
            case twoFactorRequired(LocalAgent.Error)
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()
                ._printChanges()
                .logActions(.connectionLogger)
        }
        Reduce { state, action in
            switch action {
            case .onStart:
                return .merge(
                    .send(.connection(.input(.onLaunch))),
                    .run { [killSwitchMode = $killSwitchMode] send in
                        for await value in killSwitchMode.publisher.removeDuplicates().values.dropFirst() {
                            await send(.killSwitchModeChanged(value))
                        }
                    }
                    .cancellable(id: CancelID.killSwitchMode),
                    .run { send in
                        let stream = await connectionCommandClient.stream()
                        for await command in stream {
                            await send(.commandReceived(command))
                        }
                    }
                    .cancellable(id: CancelID.connectionCommands)
                )

            case let .killSwitchModeChanged(mode):
                log.info(
                    "Kill switch mode changed",
                    category: .connectionConnect,
                    metadata: ["mode": "\(mode)"]
                )
                // If we're in zero-peer and the new mode no longer wants persistent blocking (Off or Standard), tear
                // the tunnel down so the user regains connectivity.
                if !mode.isAdvanced, state.connectionState.is(\.killSwitchActive) {
                    return .send(.connection(.input(.disconnect)))
                }
                // Otherwise, leave the tunnel untouched.
                return .none

            case let .commandReceived(.connect(spec, connectionProtocol, trigger)):
                if trigger == .changeServer {
                    let availability = authorizer.serverChangeAvailability()
                    if case .unavailable = availability {
                        log.error("Connect via .changeServer trigger reached the command handler while unauthorized")
                        return .none
                    }
                }
                let pending = PendingConnect(spec: spec, connectionProtocol: connectionProtocol, trigger: trigger)
                if let alert = interceptAlert(for: pending) {
                    state.alert = alert
                    return .none
                }
                return performConnect(pending: pending)

            case let .commandReceived(.disconnect(trigger, completion)):
                // Warn before an intentional disconnect that would leave the device offline.
                if completion == nil,
                   !Self.advancedKillSwitchConfirmationExemptTriggers.contains(trigger),
                   killSwitchMode.isAdvanced,
                   state.connectionState.is(\.connected),
                   state.connectionState.tunnelKillSwitch {
                    state.alert = confirmDisconnectWithAdvancedKillSwitchAlert(trigger: trigger)
                    return .none
                }
                return performDisconnect(trigger: trigger, completion: completion, state: state)

            case .commandReceived(.retry):
                let spec = ConnectionSpec.defaultFastest // TODO: ProTUN: Fix this!
                let intent = ConnectionPreparationIntent(
                    spec: spec,
                    acceptableProtocols: .all
                )
                log.info(
                    "Reconnecting via retry command",
                    category: .connectionConnect,
                    metadata: ["spec.location": "\(spec.location)"]
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)

            case let .commandReceived(.reconnect(connectionProtocol)):
                let spec = ConnectionSpec.defaultFastest // TODO: ProTUN: Fix this!
                let intent = ConnectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol,
                    acceptableProtocols: .all
                )
                log.info(
                    "Reconnecting via reconnect command",
                    category: .connectionConnect,
                    metadata: ["spec.location": "\(spec.location)"]
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)

            case let .commandReceived(.applySettings(settings)):
                return .send(.connection(.input(.applySettings(settings))))

            case let .commandReceived(.clearConnectionData(completion)):
                return .run { send in
                    await send(.connection(.input(.onLogout)))
                    await completion?()
                }

            case let .alert(.presented(.enableKillSwitchAndConnect(pending))):
                // Bad-LAN intercept: enabling Standard is enough to suppress the warning on retry.
                $killSwitchMode.withLock { $0 = .standard }
                return performConnect(pending: pending)

            case let .alert(.presented(.connectAnywayDespiteBadLAN(pending))):
                return performConnect(pending: pending)

            case let .alert(.presented(.confirmDisconnectWithAdvancedKillSwitch(trigger))):
                // No completion -> no intercept, proceed with normal disconnection
                return performDisconnect(trigger: trigger, completion: nil, state: state)

            case let .connection(.delegate(.connectionFailed(error))):
                SentryHelper.shared?.log(error: error)
                state.alert = domainAlertState(from: error.alert)
                return .send(.delegate(.connectionFailed(error)))

            case let .connection(.delegate(.stateChanged(connectionState))):
                log.debug("Connection layer state update \(connectionState)")
                // ProTUN's `ConnectionFeature` no longer emits `.delegate(.disconnected)`; drain any queued disconnect
                // completions when the layer reports a disconnected state. (or zero-peer KS, which fulfills the user's
                // disconnect intent).
                return .run { _ in
                    if connectionState.is(\.disconnected) || connectionState.is(\.killSwitchActive) {
                        await pendingDisconnectCompletions.drainAndInvoke()
                    }
                }

            case let .connection(.delegate(.intentResolutionFailed(_, resolutionError))):
                SentryHelper.shared?.log(error: resolutionError)
                return .send(.delegate(.intentResolutionFailed(resolutionError)))

            case let .connection(.delegate(.localAgentNotice(error))):
                if error.twoFactorRequired {
                    // The FIDO/2FA notice needs its own actions, so Home presents the sheet while ConnectionCommands
                    // still lives here (for now).
                    return .send(.delegate(.twoFactorRequired(error)))
                }
                if error.settingWasRefused {
                    // The connection layer took care of the error handling for us, we just need to alert here.
                    state.alert = settingRefusedAlert(for: error)
                }
                return .none

            case .connection, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

private extension ConnectionCommandsFeature {
    func domainAlertState(from alert: Domain.Alert) -> AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: alert.title))
        } message: {
            TextState(String(localized: alert.message))
        }
    }

    /// Informational alert telling the user the server refused one of their requested settings. The extension has
    /// already reverted the setting so there is nothing to act on.
    func settingRefusedAlert(for error: LocalAgent.Error) -> AlertState<Action.Alert> {
        let message = if let name = Self.refusedSettingName(for: error) {
            Localizable.localAgentSettingRefusedMessage(name)
        } else {
            Localizable.localAgentSettingRefusedMessageGeneric
        }
        return AlertState {
            TextState(Localizable.localAgentSettingRefusedTitle)
        } message: {
            TextState(message)
        }
    }

    /// The user-facing name of the app feature behind a refused LocalAgent setting, or `nil` for settings the app
    /// doesn't directly control (in which case the alert uses generic copy).
    static func refusedSettingName(for error: LocalAgent.Error) -> String? {
        assert(error.settingWasRefused, "Unexpected error: \(error) was not a refused setting error")

        return switch error {
        case .netShieldSettingRefused:
            Localizable.netshieldTitle
        case .portForwardingSettingRefused:
            Localizable.portForwarding
        case .randomNatSettingRefused:
            Localizable.moderateNatTitle
        case .splitTcpSettingRefused:
            Localizable.vpnAcceleratorTitle
        case .bouncingSettingRefused,
             .safeModeSettingRefused,
             .unknownSettingRefused:
            nil
        case .authenticationExpired,
             .authenticationRequired,
             .authenticationLocationChanged:
            nil
        }
    }

    /// Confirmation shown before an intentional disconnect while Advanced killswitch is active
    func confirmDisconnectWithAdvancedKillSwitchAlert(trigger: UserInitiatedVPNChange.VPNTrigger) -> AlertState<Action.Alert> {
        AlertState {
            TextState(Localizable.killSwitchAdvancedDisconnectWarning)
        } actions: {
            ButtonState(role: .cancel) {
                TextState(Localizable.cancel)
            }
            ButtonState(action: .confirmDisconnectWithAdvancedKillSwitch(trigger)) {
                TextState(Localizable.settingsProtocolAlertButtonContinue)
            }
        }
    }

    /// Encapsulates the side effects of dispatching a `.disconnect` command once the Advanced kill switch confirmation
    /// (if any) has been resolved: cancel any in-flight connect command, settle the completion, post the trigger, and
    /// hand the disconnect to the connection.
    func performDisconnect(
        trigger: UserInitiatedVPNChange.VPNTrigger,
        completion: (@MainActor @Sendable () -> Void)?,
        state: State
    ) -> Effect<Action> {
        let alreadyDisconnected = state.connectionState.is(\.disconnected) || state.connectionState.is(\.killSwitchActive)
        return .merge(
            .cancel(id: CancelID.connectionConnectCommandEffect),
            .run { @MainActor send in
                if let completion {
                    if alreadyDisconnected {
                        completion()
                    } else {
                        await pendingDisconnectCompletions.enqueue(completion)
                    }
                }
                AppEvent.userInitiatedVPNChange.post(trigger)
                await send(.connection(.input(.disconnect)))
            }
        )
    }

    /// Encapsulates the side effects of dispatching a `.connect` command after intercept checks have been resolved
    /// (either none fired or the user confirmed via alert).
    func performConnect(pending: PendingConnect) -> Effect<Action> {
        let intent = ConnectionPreparationIntent(
            spec: pending.spec,
            connectionProtocol: pending.connectionProtocol,
            acceptableProtocols: .all
        )
        return .run { [trigger = pending.trigger] send in
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(trigger))
            await send(.connection(.input(.connect(intent))))
        }
        .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
    }

    /// Returns an alert if any pre-connect intercept (e.g. misconfigured LAN) applies to the pending connect; otherwise
    /// `nil`.
    func interceptAlert(for pending: PendingConnect) -> AlertState<Action.Alert>? {
        @SharedReader(.featureFlags) var featureFlags
        if featureFlags.unsafeLanWarnings,
           !killSwitchMode.isProtected,
           let bad = networkInterfacePropertiesProvider.firstBadInterface() {
            return bad.interceptAlert(
                enableKillSwitch: .enableKillSwitchAndConnect(pending),
                connectAnyway: .connectAnywayDespiteBadLAN(pending)
            )
        }
        return nil
    }
}
