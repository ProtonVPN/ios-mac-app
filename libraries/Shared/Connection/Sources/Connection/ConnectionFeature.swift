//
//  Created on 18/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Clocks
import ComposableArchitecture
import CoreConnection
import Dependencies
import Domain
import ExtensionManager
import ExtensionSync
import Foundation
import IPCDefinitions
import Sharing
import VPNAppCore

@Reducer
public struct ConnectionFeature: Sendable {
    @Dependency(\.sessionChangeNotifier) private var sessionChangeNotifier
    @Dependency(\.connectionIntentResolver) private var intentResolver
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer
    @Dependency(\.connectionFeatureProvider) private var connectionFeatureProvider
    @Dependency(\.date) private var date

    public init() {}

    public struct State: Equatable, Sendable {
        @SharedReader(.userTier) public var userTier: VpnTier?

        @Shared(.connectionState) var connectionState
        @Shared(.serverConnectionIntent) var serverConnectionIntent
        var shouldRegisterServerChangeOnConnection: Bool // TODO: ProTUN: post connection events that some other component can hook into to do this, similarly to Telemetry
        var tunnel: ExtensionFeature.State

        /// Intent flag: we are (or should be) blocking via zero-peer. Survives a tunnel drop so an
        /// unexpected disconnect while Advanced KS is on can re-block. Distinct from the resolved
        /// `connectionState.killSwitchActive`. Whether the live tunnel actually carries the kill switch
        /// flag is not stashed here: it is reported with the tunnel state (`ConnectionState.tunnelKillSwitch`).
        var isBlockingIntended: Bool = false

        package init(
            shouldRegisterServerChangeOnConnection: Bool,
            tunnel: ExtensionFeature.State
        ) {
            self.shouldRegisterServerChangeOnConnection = shouldRegisterServerChangeOnConnection
            self.tunnel = tunnel
        }

        func updateConnectionState(_ build: (ConnectionState) -> ConnectionState) {
            let current = connectionState
            let newValue = build(current)
            guard current != newValue else { return }
            $connectionState.withLock { $0 = newValue }
        }

        /// ``updateConnectionState(_:)`` for a value the caller has already worked out.
        func setConnectionState(_ newValue: ConnectionState) {
            updateConnectionState { _ in newValue }
        }
    }

    @DebugDescription
    public enum Action: Sendable {
        case prepare(ConnectionPreparationIntent)
        case finishedPreparing(Result<ServerConnectionIntent, IntentResolutionError>)
        case tunnel(ExtensionFeature.Action)
        case input(Input)
        case delegate(Delegate)
        case connectionStateUpdated(ConnectionState)
        case reloadWidgetTimelines(ConnectionState)
        case stopObserving

        /// A subset of this reducer's actions suitable to be sent from outside
        @DebugDescription
        @CasePathable
        public enum Input: Sendable {
            case onLaunch
            case onLogout
            case connect(ConnectionPreparationIntent)
            case applySettings(Set<ConnectionFeatureChange>)
            case onSessionChange
            case disconnect
        }

        /// A subset of this reducer's actions that must be handled appropriately by its parent
        @DebugDescription
        @CasePathable
        @dynamicMemberLookup
        public enum Delegate: Sendable {
            case stateChanged(ConnectionState)
            case connectionFailed(ConnectionError)
            case intentResolutionFailed(ConnectionPreparationIntent, with: ConnectionIntentResolutionError)
            /// A user-relevant notice surfaced by the LocalAgent (e.g. a fresh 2FA is required, or the server
            /// refused a requested setting). The parent decides how to present it.
            case localAgentNotice(LocalAgent.Error)
        }
    }

    private enum CancelID {
        case preparation
        case observation
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.tunnel, action: \.tunnel) { ExtensionFeature() }
        Reduce { state, action in
            switch action {
            case .input(.onLaunch):
                return .merge(
                    .send(.tunnel(.startObserving)),
                    // Listen for session changes (logout or guest --> authenticated transitions)
                    .listen(to: sessionChangeNotifier.stream()) { _ in .input(.onSessionChange) }
                ).cancellable(id: CancelID.observation, cancelInFlight: true)

            case .stopObserving:
                return .merge(.send(.tunnel(.stopObserving)), .cancel(id: CancelID.observation))

            case let .input(.connect(intent)):
                do throws(ConnectionIntentResolutionError) {
                    try intentResolver.authorize(intent, state.userTier.orFree)
                } catch {
                    return .send(.delegate(.intentResolutionFailed(intent, with: error)))
                }

                // A fresh connect clears any standing blocking intent: the user is explicitly connecting.
                // The configurator sets `includeAllNetworks` from the current KS mode, and the projection
                // reports it back as `ConnectionState.tunnelKillSwitch`.
                state.isBlockingIntended = false

                // Transition to connecting to give the user immediate feedback while we perform the somewhat expensive
                // database operations to resolve the server.
                state.updateConnectionState {
                    .connecting(.unresolved(intent), tunnelActive: $0.tunnelActive)
                }
                return .send(.prepare(intent))

            case let .input(.applySettings(featureChanges)):
                // Input goes directly to the tunnel IPC which requests the new features. Both agent
                // features (applied by the Local Agent) and tunnel features (e.g. protocol, applied
                // by the extension in place) are carried in a single configuration update.
                log.info("applySettings", category: .connection, metadata: ["features": "\(featureChanges)"])
                var update = ConnectionUpdate()
                for change in featureChanges {
                    switch change {
                    case let .agent(.netShield(type)): update.netShield = type
                    case let .agent(.vpnAccelerator(enabled)): update.vpnAccelerator = enabled
                    case let .agent(.moderateNAT(type)): update.moderateNAT = type
                    case let .agent(.portForwarding(enabled)): update.portForwarding = enabled
                    case let .tunnel(.connectionProtocol(connectionProtocol)): update.connectionProtocol = connectionProtocol
                    case let .tunnel(.killSwitch(enabled)): update.killSwitch = enabled
                    case let .tunnel(.allowLAN(enabled)): update.allowLAN = enabled
                    case let .tunnel(.customDNS(resolvers)): update.customDNS = resolvers
                    }
                }
                log.debug("Connection update", category: .connection, metadata: ["update": "\(update)"])
                if update.killSwitch == false, state.connectionState.is(\.killSwitchActive) {
                    // Disabling KS while zero-peer blocking must tear the tunnel down: a bare `killSwitch=false`
                    // config change can't exit zero-peer mode (that needs a peer/location update). The next
                    // connection will rebuild the tunnel with the location selected by the user.
                    state.isBlockingIntended = false
                    return .merge(
                        .cancel(id: CancelID.preparation),
                        .send(.tunnel(.disconnect(nil))) // this sets `onDemand` to `false`
                    )
                }
                // Apply the feature change to the live session over IPC.
                // Enabling KS does not force a reconnect.
                return .send(.tunnel(.requestConfigChange(update)))

            case .input(.disconnect):
                if let enterBlocking = enterZeroPeerBlockingIfNeeded(&state) {
                    return enterBlocking
                }
                // An established blackhole persists through disconnect requests (e.g. from the widget)
                // for as long as the mode stays Advanced. It only releases once the user leaves
                // Advanced: the mode-change paths send this same action after the downgrade, at which
                // point this guard no longer holds.
                if state.connectionState.is(\.killSwitchActive),
                   connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced {
                    return .none
                }
                // The tunnel releases on user intent. The state keeps following the tunnel reports,
                // walking through disconnecting to disconnected.
                state.isBlockingIntended = false
                return .merge(.cancel(id: CancelID.preparation), .send(.tunnel(.disconnect(nil))))

            case .input(.onLogout):
                // Advanced kill switch keeps blocking across sign-out: switch a live kill switch tunnel
                // to zero-peer blocking, or leave an already blocking tunnel alone. In every other case
                // tear the tunnel down, so the user is neither left connected nor locked out on the
                // login screen.
                if let enterBlocking = enterZeroPeerBlockingIfNeeded(&state) {
                    return .merge(.send(.stopObserving), enterBlocking)
                }
                if state.connectionState.is(\.killSwitchActive),
                   connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced {
                    return .send(.stopObserving)
                }
                return .merge(.send(.stopObserving), .send(.tunnel(.cleanup)))

            case .input(.onSessionChange):
                return .send(.tunnel(.cleanup))

            case let .prepare(intent):
                state.shouldRegisterServerChangeOnConnection = intent.spec.location == .any(.random)
                return .run { send in
                    // Let's perform server selection asynchronously
                    do throws(IntentResolutionError) {
                        let result = try await intentResolver.resolve(intent)
                        return await send(.finishedPreparing(.success(result)))
                    } catch {
                        return await send(.finishedPreparing(.failure(error)))
                    }
                }.cancellable(id: CancelID.preparation, cancelInFlight: true)

            case let .finishedPreparing(.success(resolvedIntent)):
                state.$serverConnectionIntent.withLock {
                    $0 = resolvedIntent
                }
                return .send(.tunnel(.connect(resolvedIntent)))

            case let .finishedPreparing(.failure(error)):
                log.error("Failed to preparing connection with error: \(error)")
                // Revert state to actual tunnel state
                state.updateConnectionState {
                    ConnectionState(tunnel: state.tunnel, fallbackSpec: $0.resolvedSpec)
                }
                return .send(.delegate(.connectionFailed(.preparation(.intentResolution(error)))))

            case let .tunnel(.tunnelStatusChanged(.disconnected(disconnectError))):
                #if !os(tvOS)
                    if state.isBlockingIntended,
                       state.connectionState.is(\.connected) || state.connectionState.is(\.killSwitchActive),
                       connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced {
                        // The tunnel died even though Advanced kill switch wants to keep blocking, for
                        // example because the extension crashed. Start a fresh zero-peer tunnel to
                        // restore the blackhole. Any disconnect error is deliberately swallowed here:
                        // a `.delegate(.connectionFailed)` would invite the parent to run its failure
                        // handling (alerts, disconnect flows) while the protection is being restored,
                        // so it must NOT be emitted from this branch.
                        // This branch requires `connectionState` to still read connected or blocking,
                        // and the line below sets it to disconnected, so the start is attempted once:
                        // if the fresh tunnel fails, further disconnected reports skip this branch.
                        // The state becomes `.killSwitchActive` only once the extension confirms the
                        // new tunnel is up, since reporting it earlier would overstate the protection.
                        state.updateConnectionState {
                            ConnectionState(tunnel: state.tunnel, fallbackSpec: $0.resolvedSpec)
                        }
                        return .send(.tunnel(.startZeroPeerColdStart))
                    }
                #endif
                state.updateConnectionState {
                    ConnectionState(tunnel: state.tunnel, fallbackSpec: $0.resolvedSpec)
                }
                guard let disconnectError else { return .none }
                state.isBlockingIntended = false
                return .send(.delegate(.connectionFailed(.tunnel(disconnectError))))

            case let .tunnel(.tunnelStatusChanged(.connected(_, connectionData))):
                log.info(
                    "Tunnel connection finished",
                    category: .connection,
                    metadata: ["date": "\(connectionData.connectionDate)", "serverID": "\(connectionData.currentPeerId ?? "")"]
                )
                if state.shouldRegisterServerChangeOnConnection {
                    serverChangeAuthorizer.registerServerChange(connectedAt: date.now)
                    state.shouldRegisterServerChangeOnConnection = false
                }
                state.updateConnectionState {
                    ConnectionState(tunnel: state.tunnel, fallbackSpec: $0.resolvedSpec)
                }
                // Advanced KS "activates" on a successful connection: from Armed → Active. Mark the
                // intent so a later intentional disconnect or unexpected drop keeps blocking. The session/tokens
                // this connection cached let the subsequent zero-peer block skip a fresh fork.
                if connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced {
                    state.isBlockingIntended = true
                }
                return .none

            case .tunnel(.tunnelStatusChanged):
                let incoming = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                if incoming.is(\.killSwitchActive) {
                    // Zero-peer blocking is active (cold start success, or the app relaunched into a blocking
                    // tunnel).
                    state.isBlockingIntended = true
                    state.setConnectionState(incoming)
                    // Blocking may only persist under Advanced. If the mode was downgraded while the switch
                    // to zero-peer was still in flight, or a stale blocking tunnel resurfaced, release it.
                    guard connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced else {
                        return .send(.input(.disconnect))
                    }
                    return .none
                }
                state.setConnectionState(incoming)
                if case .connectingToLocalAgent(_, _, .hardJailed, .need2Fa) = state.tunnel {
                    return .send(.delegate(.localAgentNotice(.authenticationRequired)))
                }
                return .none

            case let .tunnel(.delegate(.timedOut(stage))):
                return .send(.delegate(.connectionFailed(.timeout(stage))))

            case let .tunnel(.delegate(.reconfigurationFailed(error))):
                // Reconfiguring an already-running tunnel failed. Make sure we have an accurate view of the current
                // tunnel state in case the extension couldn't notify us, and then surface the error.
                state.updateConnectionState {
                    ConnectionState(tunnel: state.tunnel, fallbackSpec: $0.resolvedSpec)
                }
                return .send(.delegate(.connectionFailed(.tunnel(.reconfigurationFailure(error)))))

            case let .tunnel(.delegate(.errorReported(error))):
                // Decode the transport-level error and forward only the user-relevant classes up as notices.
                if let localAgentError = error.decoded(as: LocalAgent.Error.self) {
                    log.error("Local agent error", category: .connection, metadata: ["error": "\(error)"])
                    return .send(.delegate(.localAgentNotice(localAgentError)))
                } else if let apiError = error.decoded(as: APIError.self) {
                    // We'll get a connection failure notice soon, but log the error at least. Read the *body* code, not
                    // the HTTP one: `APIHTTPErrorCode.unprocessableEntity` describes every 422 as an expired session,
                    // which is often wrong. A 422/2001 during connection is "Invalid selector" — ProTUN replaying a
                    // fork selector it already consumed after its certificate refresh failed. That is terminal: it
                    // never asks for a fresh selector, so pushing one does not help and the attempt cannot recover.
                    log.error("Extension encountered an API error: \(optional: apiError.httpErrorCode) (\(apiError.apiErrorCode))", category: .connection)
                } else {
                    // All other unhandled errors get logged wholesale.
                    log.error("Extension encountered an unhandled error", category: .connection, metadata: ["error": "\(error)"])
                }

                // Log all other unactionable errors as diagnostics.
                SentryHelper.shared?.log(error: error)
                return .none

            case .tunnel:
                return .none

            case let .connectionStateUpdated(newValue):
                return .merge(
                    .send(.delegate(.stateChanged(newValue))),
                    .send(.reloadWidgetTimelines(newValue))
                )

            case let .reloadWidgetTimelines(connectionState):
                @Dependency(\.widgetReload) var widgetReload
                widgetReload.reloadAllTimelines(.connectionStateChanged(connectionState.widgetReloadChange))
                return .none

            case .delegate:
                // It's up to the parent feature to respond to delegate actions
                return .none
            }
        }
        .onChange(of: \.connectionState) { _, newValue in
            Reduce { _, _ in
                .send(.connectionStateUpdated(newValue))
            }
        }
    }

    /// Switches a live kill switch tunnel to zero-peer blocking, if Advanced kill switch is Active.
    /// Active means the connected tunnel actually carries the kill switch flag. Enabling Advanced
    /// mid-session only requests the flag for the next connection, so in that case, and for the
    /// Standard and Off modes, this returns nil and the caller releases the tunnel instead.
    private func enterZeroPeerBlockingIfNeeded(_ state: inout State) -> Effect<Action>? {
        guard connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced,
              case let .connected(tunnelConfig, _) = state.connectionState,
              tunnelConfig.killSwitch else {
            return nil
        }
        state.isBlockingIntended = true
        return .send(.tunnel(.requestConfigChange(.zeroPeer(using: tunnelConfig.connectionSpec))))
    }
}

extension ConnectionState {
    var widgetReloadChange: WidgetReloadReason.ConnectionStateChange {
        switch self {
        case .connected:
            .connected
        case .resolving, .connecting, .authenticationRequired:
            .connecting
        case .disconnected, .disconnecting, .killSwitchActive:
            .disconnected
        }
    }
}

// User-facing connection state
@DebugDescription
@CasePathable
public enum ConnectionState: Equatable, Sendable, Codable {
    case resolving
    case disconnected
    case disconnecting(TunnelProtocol, ConnectionSpec)
    /// A connection attempt is underway. `tunnelActive` reports whether an interface already holds the user's traffic,
    /// which stays during peer handover.
    case connecting(Intent, tunnelActive: Bool)
    /// The tunnel is established and blocking traffic until the user completes authentication.
    case authenticationRequired(Intent, tunnelActive: Bool)
    /// The connected state is split across ``TunnelConfiguration`` (which is unlikely to change without user interaction),
    /// and `ResolvedDynamicConnectionData` which is the more transient/dynamic data.
    case connected(TunnelConfiguration, ResolvedDynamicConnectionData)
    case killSwitchActive(ConnectionSpec, TunnelConfiguration)

    @DebugDescription
    @CasePathable
    public enum Intent: Equatable, Sendable, Codable {
        case unresolved(ConnectionPreparationIntent)
        case resolved(ResolvedConnectionIntent)
    }

    /// Same as DynamicConnectionData, but the peerId string has been resolved to an actual server
    @DebugDescription
    public struct ResolvedDynamicConnectionData: Equatable, Sendable, Codable {
        /// The ID of the peer we are connected to
        public let currentPeer: Server

        /// The date at which the tunnel first entered the `connected` state.
        public let connectionDate: Date

        /// Protocol specific data
        public let protocolConnectionData: ProtocolConnectionData

        public init(
            currentPeer: Server,
            connectionDate: Date,
            protocolConnectionData: ProtocolConnectionData
        ) {
            self.currentPeer = currentPeer
            self.connectionDate = connectionDate
            self.protocolConnectionData = protocolConnectionData
        }
    }
}

public extension ConnectionFeature.State {
    /// A fresh starting state.
    ///
    /// This is computed rather than stored. The `@Shared` properties bind to the `defaultAppStorage` that is in
    /// effect when the value is created, and a stored `static let` is created once per process. Every later caller
    /// would then receive that first store, so a test or a preview that scopes `defaultAppStorage` to its own
    /// `UserDefaults` would read and write a different `connectionState` than the rest of the feature it drives.
    static var initialState: ConnectionFeature.State {
        ConnectionFeature.State(
            shouldRegisterServerChangeOnConnection: false,
            tunnel: .unknown
        )
    }
}

extension ConnectionFeature.Action: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .prepare(intent):
            ".prepare(\(intent))"
        case let .finishedPreparing(result):
            ".finishedPreparing(\(result))"
        case let .tunnel(action):
            ".tunnel(\(action.debugDescription))"
        case let .input(input):
            ".input(\(input.debugDescription))"
        case let .delegate(delegate):
            ".delegate(\(delegate.debugDescription))"
        case .stopObserving:
            ".stopObserving"
        case let .connectionStateUpdated(connectionState):
            ".connectionStateUpdated(\(connectionState.debugDescription)"
        case .reloadWidgetTimelines:
            ".reloadWidgetTimelines"
        }
    }
}

extension ConnectionFeature.Action.Input: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .onLaunch:
            ".onLaunch"
        case .onLogout:
            ".onLogout"
        case let .connect(intent):
            ".connect(\(intent))"
        case let .applySettings(settings):
            ".applySettings(\(settings))"
        case .disconnect:
            ".disconnect"
        case .onSessionChange:
            ".onSessionChange"
        }
    }
}

extension ConnectionFeature.Action.Delegate: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .stateChanged(connectionState):
            ".stateChanged(\(connectionState))"
        case let .connectionFailed(connectionError):
            ".connectionFailed(\(connectionError))"
        case let .intentResolutionFailed(intent, resolutionError):
            ".intentResolutionFailed(\(intent), \(resolutionError))"
        case let .localAgentNotice(error):
            ".localAgentNotice(\(error))"
        }
    }
}

extension ConnectionState: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .resolving:
            ".resolving"
        case .disconnected:
            ".disconnected"
        case let .disconnecting(intent, server):
            ".disconnecting(intent: \(intent), server: \(server))"
        case let .connecting(intent):
            ".connecting(\(intent))"
        case let .authenticationRequired(intent, tunnelActive):
            ".authenticationRequired(\(intent), tunnelActive: \(tunnelActive))"
        case let .connected(tunnelConfig, connectionData):
            ".connected(\(tunnelConfig), \(connectionData))"
        case let .killSwitchActive(spec, tunnelConfig):
            ".killSwitchActive(\(spec), \(tunnelConfig))"
        }
    }

    public var basicDescription: String {
        switch self {
        case .resolving:
            ".resolving"
        case .disconnected:
            ".disconnected"
        case .disconnecting:
            ".disconnecting"
        case .connecting:
            ".connecting"
        case .authenticationRequired:
            ".authenticationRequired"
        case .connected:
            ".connected"
        case .killSwitchActive:
            ".killSwitchActive"
        }
    }
}

extension ConnectionState.Intent: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .unresolved(intent):
            ".unresolved(\(intent))"
        case let .resolved(intent):
            ".resolved(\(intent))"
        }
    }
}

public extension ConnectionState {
    /// Whether the reported tunnel carries the kill switch flag (`includeAllNetworks`): connected
    /// traffic blocks instead of leaking when the tunnel drops, and a zero-peer tunnel is the
    /// blackhole already. `false` whenever there is no live tunnel to read the flag from.
    var tunnelKillSwitch: Bool {
        switch self {
        case let .connected(configuration, _), let .killSwitchActive(_, configuration):
            configuration.killSwitch
        default:
            false
        }
    }
}

extension ConnectionState {
    /// IKE configurations have no `connectionSpec`, that's why we need a `fallbackSpec` for IKE.
    init(tunnel: ExtensionFeature.State, fallbackSpec: ConnectionSpec? = nil) {
        @Dependency(\.serverIdentifier) var identifier

        func resolvedSpec(for tunnelConfig: TunnelConfiguration) -> ConnectionSpec {
            #if os(macOS)
                guard tunnelConfig.tunnelProtocol == .ike, let fallbackSpec else {
                    return tunnelConfig.connectionSpec
                }
                return fallbackSpec
            #else
                return tunnelConfig.connectionSpec
            #endif
        }

        func resolvedIntent(for tunnelConfig: TunnelConfiguration) -> ResolvedConnectionIntent? {
            guard let peerID = tunnelConfig.peerIDs.first, let server = identifier.fullServerInfo(peerID) else {
                return nil
            }
            return ResolvedConnectionIntent(
                spec: resolvedSpec(for: tunnelConfig),
                tunnelProtocol: tunnelConfig.tunnelProtocol,
                resolvedServer: server
            )
        }

        switch tunnel {
        case .unknown:
            self = .resolving

        case let .connectingToLocalAgent(tunnelConfig, tunnelActive, .hardJailed, .need2Fa):
            #if os(macOS)
                assert(tunnelConfig.tunnelProtocol != .ike, "IKE should have no local agent")
            #endif
            guard let intent = resolvedIntent(for: tunnelConfig) else {
                self = .resolving
                return
            }
            self = .authenticationRequired(.resolved(intent), tunnelActive: tunnelActive)

        case let .connectingToLocalAgent(tunnelConfig, tunnelActive, _, _):
            #if os(macOS)
                assert(tunnelConfig.tunnelProtocol != .ike, "IKE should have no local agent")
            #endif
            fallthrough

        case let .connecting(tunnelConfig, tunnelActive):
            guard let intent = resolvedIntent(for: tunnelConfig) else {
                self = .resolving
                return
            }
            self = .connecting(.resolved(intent), tunnelActive: tunnelActive)

        case .reasserting:
            // TODO: ProTUN: Expand connecting state with information from provider config/mmap
            self = .resolving

        case let .connected(tunnelConfig, connectionData):
            guard let peerID = connectionData.currentPeerId,
                  let server = identifier.fullServerInfo(peerID) else {
                log.error("Server with id \(optional: connectionData.currentPeerId) not found")
                self = .resolving
                return
            }
            let resolvedData = ResolvedDynamicConnectionData(
                currentPeer: server,
                connectionDate: connectionData.connectionDate,
                protocolConnectionData: connectionData.protocolConnectionData
            )

            let resolvedConfig = TunnelConfiguration(
                connectionSpec: resolvedSpec(for: tunnelConfig),
                tunnelProtocol: tunnelConfig.tunnelProtocol,
                peerIDs: tunnelConfig.peerIDs,
                killSwitch: tunnelConfig.killSwitch
            )
            self = .connected(resolvedConfig, resolvedData)

        case let .disconnecting(tunnelConfig):
            // TODO: ProTUN: Expand disconnecting state with information from provider config/mmap
            self = .disconnecting(tunnelConfig.tunnelProtocol, resolvedSpec(for: tunnelConfig))

        case .disconnected:
            self = .disconnected

        case .invalid:
            self = .disconnected

        case let .killSwitchActive(tunnelConfig):
            self = .killSwitchActive(resolvedSpec(for: tunnelConfig), tunnelConfig)
        }
    }
}
