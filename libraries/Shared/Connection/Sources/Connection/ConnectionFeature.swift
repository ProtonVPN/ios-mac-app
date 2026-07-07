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
#if canImport(WidgetKit)
import WidgetKit
#endif

@Reducer
public struct ConnectionFeature: Sendable {
    @Dependency(\.sessionChangeNotifier) private var sessionChangeNotifier
    @Dependency(\.connectionIntentResolver) private var intentResolver
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer
    @Dependency(\.connectionFeatureProvider) private var connectionFeatureProvider

    public init() {}

    public struct State: Equatable, Sendable {
        @SharedReader(.userTier) public var userTier: Int?

        @Shared(.connectionState) var connectionState
        var shouldRegisterServerChangeOnConnection: Bool // TODO: ProTUN: post connection events that some other component can hook into to do this, similarly to Telemetry
        var tunnel: ExtensionFeature.State

        /// Whether the live tunnel was started with `includeAllNetworks = true`
        /// Advanced KS disconnect can switch to zero-peer in place or must cold-start a fresh blocking tunnel
        var tunnelArmedForKillSwitch: Bool = false
        /// Intent flag: we are (or should be) blocking via zero-peer. Survives a tunnel drop so an
        /// unexpected disconnect while Advanced KS is on can re-block. Distinct from the resolved
        /// `connectionState.killSwitchActive`
        var isBlockingIntended: Bool = false
        /// One-shot guard so a failed Advanced KS re-block can't spin into a retry loop
        var isAttemptingZeroPeerReblock: Bool = false
        /// Set while tearing the tunnel down purely to re-arm `includeAllNetworks`; once we observe
        /// `.disconnected`, cold-start a fresh connect to this spec
        var pendingReconnectSpec: ConnectionSpec?

        package init(
            shouldRegisterServerChangeOnConnection: Bool,
            tunnel: ExtensionFeature.State
        ) {
            self.shouldRegisterServerChangeOnConnection = shouldRegisterServerChangeOnConnection
            self.tunnel = tunnel
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
        case reloadWidgetTimelines
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
            /// Enter Advanced kill switch blocking from a disconnected state (cold-start).
            case enterZeroPeerBlocking
            /// Fully restart the tunnel, reconnecting to `spec`, to re-arm `includeAllNetworks`
            /// (which can't be applied to a live session).
            case reconnect(ConnectionSpec)
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
                    try intentResolver.authorize(intent, state.userTier ?? .freeTier)
                } catch {
                    return .send(.delegate(.intentResolutionFailed(intent, with: error)))
                }

                // A fresh connect sets `includeAllNetworks` from the current KS mode and clears any pending
                // zero-peer re-block (the user is explicitly connecting)
                state.isAttemptingZeroPeerReblock = false
                state.isBlockingIntended = false
                state.tunnelArmedForKillSwitch = connectionFeatureProvider.requestedFeatures().killSwitch

                // Transition to connecting to give the user immediate feedback while
                // we perform the somewhat expensive database operations to resolve the server
                state.$connectionState.withLock {
                    $0 = .connecting(.unresolved(intent))
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
                let ipcEffect: Effect<Action> = .send(.tunnel(.requestConfigChange(update)))
                // Enabling KS needs `includeAllNetworks` set in the tunnel, which can't be applied to a
                // live session. If we're connected on a tunnel that wasn't started armed, reconnect to the
                // current server so KS actually blocks on a later disconnect/drop
                let enablesKillSwitch = featureChanges.contains { change in
                    if case .tunnel(.killSwitch(true)) = change { return true }
                    return false
                }
                if enablesKillSwitch,
                   state.connectionState.is(\.connected),
                   !state.tunnelArmedForKillSwitch,
                   let spec = state.connectionState.resolvedSpec {
                    return .merge(ipcEffect, .send(.input(.reconnect(spec))))
                }
                return ipcEffect

            case .input(.disconnect):
                let mode = connectionFeatureProvider.requestedFeatures().killSwitchMode
                if mode.isAdvanced {
                    // Advanced KS keeps blocking on an intentional disconnect
                    state.isBlockingIntended = true
                    if state.tunnelArmedForKillSwitch, case let .connected(tunnelConfig, _) = state.connectionState {
                        // Live armed tunnel: switch to zero-peer in place (gap-free). Optimistic: reconciled by
                        // resolveProTUN once the applied requestId quiesces; on failure the .reconfigurationFailed
                        // handler restores connectionState from the reported tunnel state.
                        let zeroPeerConfig = TunnelConfiguration(
                            connectionSpec: tunnelConfig.connectionSpec,
                            tunnelProtocol: tunnelConfig.tunnelProtocol,
                            peerIDs: []
                        )
                        state.$connectionState.withLock {
                            $0 = .killSwitchActive(tunnelConfig.connectionSpec, zeroPeerConfig)
                        }
                        let update = ConnectionUpdate(
                            location: .init(spec: tunnelConfig.connectionSpec, peers: []),
                            killSwitch: true
                        )
                        return .send(.tunnel(.requestConfigChange(update)))
                    }
                    // Not armed, or cancelling a connect that never reached `.connected`: an in-place switch
                    // wouldn't block, so stop the tunnel; the disconnect-driven re-block (gated on
                    // `isBlockingIntended`) cold starts a fresh, armed zero-peer tunnel once we reach `.disconnected`
                    return .merge(.cancel(id: CancelID.preparation), .send(.tunnel(.disconnect(nil))))
                }
                // Standard / Off: release on user intent. Zero-peer mode has no peer to resume, so the tunnel
                // stops; projection walks the state through `.disconnecting` to `.disconnected`.
                state.isBlockingIntended = false
                return .merge(.cancel(id: CancelID.preparation), .send(.tunnel(.disconnect(nil))))

            case .input(.enterZeroPeerBlocking):
                // Cold start zero-peer blocking from a fully disconnected state (enable Advanced KS when disconnected)
                guard !state.isBlockingIntended, state.connectionState.is(\.disconnected) else { return .none }
                state.isBlockingIntended = true
                state.isAttemptingZeroPeerReblock = true
                state.tunnelArmedForKillSwitch = true // the cold-start config always sets includeAllNetworks
                return .send(.tunnel(.startZeroPeerColdStart))

            case let .input(.reconnect(spec)):
                // Tear-down to set `includeAllNetworks`; the `.disconnected` observation cold-starts
                // a fresh connect. Must NOT enter zero-peer, so we don't set `isBlockingIntended`
                state.pendingReconnectSpec = spec
                state.tunnelArmedForKillSwitch = false
                return .merge(.cancel(id: CancelID.preparation), .send(.tunnel(.disconnect(nil))))

            case .input(.onLogout):
                // Advanced KS persists across logout: keep blocking on the login screen instead of
                // tearing the tunnel down. Standard/Off release so the user isn't locked out
                if connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced {
                    if case let .connected(tunnelConfig, _) = state.connectionState {
                        state.isBlockingIntended = true
                        let zeroPeerConfig = TunnelConfiguration(
                            connectionSpec: tunnelConfig.connectionSpec,
                            tunnelProtocol: tunnelConfig.tunnelProtocol,
                            peerIDs: []
                        )
                        state.$connectionState.withLock {
                            $0 = .killSwitchActive(tunnelConfig.connectionSpec, zeroPeerConfig)
                        }
                        let update = ConnectionUpdate(
                            location: .init(spec: tunnelConfig.connectionSpec, peers: []),
                            killSwitch: true
                        )
                        return .merge(
                            .send(.stopObserving),
                            .send(.tunnel(.requestConfigChange(update)))
                        )
                    }
                    // Already blocking or disconnected: leave the firewall untouched, just stop observing
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
                return .send(.tunnel(.connect(resolvedIntent)))

            case let .finishedPreparing(.failure(error)):
                log.error("Failed to preparing connection with error: \(error)")
                // Revert state to actual tunnel state
                state.$connectionState.withLock {
                    $0 = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                }
                return .send(.delegate(.connectionFailed(.preparation(.intentResolution(error)))))

            case let .tunnel(.tunnelStatusChanged(tunnelState)) where tunnelState.is(\.disconnected) && state.pendingReconnectSpec != nil:
                // The tunnel finished tearing down for a re-arm; now that we're disconnected, cold start a
                // fresh connect so `includeAllNetworks` is there
                guard let spec = state.pendingReconnectSpec else { return .none }
                state.pendingReconnectSpec = nil
                return .send(.input(.connect(ConnectionPreparationIntent(spec: spec, acceptableProtocols: .all))))

            case let .tunnel(.tunnelStatusChanged(tunnelState)) where tunnelState.is(\.disconnected)
                && state.isBlockingIntended
                && !state.isAttemptingZeroPeerReblock
                && connectionFeatureProvider.requestedFeatures().killSwitchMode.isAdvanced:
                // Advanced KS: an unexpected drop (or VPN toggled off in Settings) while we were blocking →
                // one-shot cold start re-block. The guard prevents a retry loop.
                state.isAttemptingZeroPeerReblock = true
                state.tunnelArmedForKillSwitch = true // the cold-start config always sets includeAllNetworks
                return .send(.tunnel(.startZeroPeerColdStart))

            case let .tunnel(.tunnelStatusChanged(.disconnected(.some(error)))):
                state.$connectionState.withLock {
                    $0 = .disconnected
                }
                state.isBlockingIntended = false
                return .send(.delegate(.connectionFailed(.tunnel(error))))

            case let .tunnel(.tunnelStatusChanged(.connected(_, connectionData))):
                log.info(
                    "Tunnel connection finished",
                    category: .connection,
                    metadata: ["date": "\(connectionData.connectionDate)", "serverID": "\(connectionData.currentPeerId ?? "")"]
                )
                if state.shouldRegisterServerChangeOnConnection {
                    serverChangeAuthorizer.registerServerChange(connectedAt: connectionData.connectionDate)
                }
                state.$connectionState.withLock {
                    $0 = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                }
                return .none

            case .tunnel(.tunnelStatusChanged):
                let incoming = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                if incoming.is(\.killSwitchActive) {
                    // Zero-peer blocking is active (cold start success, or the app relaunched into a blocking
                    // tunnel). A zero-peer tunnel always has `includeAllNetworks`
                    state.isBlockingIntended = true
                    state.isAttemptingZeroPeerReblock = false
                    state.tunnelArmedForKillSwitch = true
                }
                state.$connectionState.withLock {
                    $0 = incoming
                }
                return .none

            case let .tunnel(.delegate(.timedOut(stage))):
                return .send(.delegate(.connectionFailed(.timeout(stage))))

            case let .tunnel(.delegate(.reconfigurationFailed(error))):
                // Reconfiguring an already-running tunnel failed. Make sure we have an accurate view of the current
                // tunnel state in case the extension couldn't notify us, and then surface the error.
                state.$connectionState.withLock {
                    $0 = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                }
                return .send(.delegate(.connectionFailed(.tunnel(.reconfigurationFailure(error)))))

            case let .tunnel(.delegate(.errorReported(error))):
                // Decode the transport-level error and forward only the user-relevant classes up as notices.
                if let localAgentError = error.decoded(as: LocalAgent.Error.self) {
                    log.error("Local agent error", category: .connection, metadata: ["error": "\(error)"])
                    return .send(.delegate(.localAgentNotice(localAgentError)))
                } else if let apiError = error.decoded(as: APIError.self) {
                    // We'll get a connection failure notice soon, but log the error at least.
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
                    .send(.reloadWidgetTimelines)
                )
            case .reloadWidgetTimelines:
#if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
#endif
                return .none
            case .delegate:
                // It's up to the parent feature to respond to delegate actions
                return .none
            }
        }
        .onChange(of: \.connectionState) { _, newValue in
            Reduce { _, _ in
                return .send(.connectionStateUpdated(newValue))
            }
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
    case connecting(Intent)
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
    static let initialState = ConnectionFeature.State(
        shouldRegisterServerChangeOnConnection: false,
        tunnel: .unknown
    )
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
        case .enterZeroPeerBlocking:
            ".enterZeroPeerBlocking"
        case let .reconnect(spec):
            ".reconnect(\(spec))"
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
        case let .connected(tunnelConfig, connectionData):
            ".connected (\(tunnelConfig), \(connectionData))"
        case let .killSwitchActive(spec, tunnelConfig):
            ".killSwitchActive(\(spec), \(tunnelConfig))"
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

extension ConnectionState {
    /// IKE configurations have no `connectionSpec`, that's why we need a `fallbackSpec` for IKE.
    init(tunnel: ExtensionFeature.State, fallbackSpec: ConnectionSpec? = nil) {
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

        switch tunnel {
        case .unknown:
            self = .resolving

        case let .connectingToLocalAgent(tunnelConfig):
            #if os(macOS)
                assert(tunnelConfig.tunnelProtocol != .ike, "IKE should have no local agent")
            #endif
            fallthrough

        case let .connecting(tunnelConfig):
            @Dependency(\.serverIdentifier) var identifier
            guard let peerID = tunnelConfig.peerIDs.first, let server = identifier.fullServerInfo(peerID) else {
                self = .resolving
                return
            }
            let intent = ResolvedConnectionIntent(
                spec: resolvedSpec(for: tunnelConfig),
                tunnelProtocol: tunnelConfig.tunnelProtocol,
                resolvedServer: server
            )
            self = .connecting(.resolved(intent))

        case .reasserting:
            // TODO: ProTUN: Expand connecting state with information from provider config/mmap
            self = .resolving

        case let .connected(tunnelConfig, connectionData):
            @Dependency(\.serverIdentifier) var identifier
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
                peerIDs: tunnelConfig.peerIDs
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
