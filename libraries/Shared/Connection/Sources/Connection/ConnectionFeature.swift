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
import Foundation
import LocalAgent
import LocalAgentIPC
import Sharing
import VPNAppCore

@Reducer
public struct ConnectionFeature: Sendable {
    @Dependency(\.sessionChangeNotifier) private var sessionChangeNotifier
    @Dependency(\.connectionIntentResolver) private var intentResolver
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer

    public init() {}

    public struct State: Equatable, Sendable {
        @SharedReader(.userTier) public var userTier: Int?

        var connectionState: ConnectionState
        var shouldRegisterServerChangeOnConnection: Bool // TODO: ProTUN: post connection events that some other component can hook into to do this, similarly to Telemetry
        var tunnel: ExtensionFeature.State

        package init(
            connectionState: ConnectionState,
            shouldRegisterServerChangeOnConnection: Bool,
            tunnel: ExtensionFeature.State
        ) {
            self.connectionState = connectionState
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
            case localAgentNotice(LocalAgentTwoFactorAuthenticationError)
            /// The extension reported an error (e.g. a requested setting was policy-refused, or a config update failed).
            case errorReported(ExtensionError)
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

                // Transition to connecting to give the user immediate feedback while
                // we perform the somewhat expensive database operations to resolve the server
                state.connectionState = ConnectionState.connecting(.unresolved(intent))
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
                    case let .tunnel(.customDNS(enabled)): update.customDNS = enabled
                    case let .tunnel(.onDemand(enabled)): update.onDemand = enabled
                    }
                }
                log.debug("Connection update", category: .connection, metadata: ["update": "\(update)"])
                return .send(.tunnel(.requestConfigChange(update)))

            case .input(.disconnect):
                return .merge(
                    .cancel(id: CancelID.preparation),
                    .send(.tunnel(.disconnect(nil)))
                )

            case .input(.onLogout):
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
                state.connectionState = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                return .send(.delegate(.connectionFailed(.preparation(.intentResolution(error)))))

            case let .tunnel(.tunnelStatusChanged(.disconnected(.some(error)))):
                state.connectionState = .disconnected
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
                state.connectionState = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                return .none

            case .tunnel(.tunnelStatusChanged):
                state.connectionState = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                return .none

            case let .tunnel(.delegate(.timedOut(stage))):
                return .send(.delegate(.connectionFailed(.timeout(stage))))

            case let .tunnel(.delegate(.reconfigurationFailed(error))):
                // Reconfiguring an already-running tunnel failed. Make sure we have an accurate view of the current
                // tunnel state in case the extension couldn't notify us, and then surface the error.
                state.connectionState = ConnectionState(tunnel: state.tunnel, fallbackSpec: state.connectionState.resolvedSpec)
                return .send(.delegate(.connectionFailed(.tunnel(.reconfigurationFailure(error)))))

            case let .tunnel(.delegate(.errorReported(error))):
                log.warning("Extension reported error", category: .connection, metadata: ["error": "\(error)"])
                SentryHelper.shared?.log(error: error)
                return .send(.delegate(.errorReported(error)))

            case .tunnel:
                return .none

            case .delegate:
                // It's up to the parent feature to respond to delegate actions
                return .none
            }
        }
        .onChange(of: \.connectionState) { _, newValue in
            Reduce { _, _ in
                .send(.delegate(.stateChanged(newValue)))
            }
        }
    }
}

// User-facing connection state
@DebugDescription
@CasePathable
public enum ConnectionState: Equatable, Sendable {
    case resolving
    case disconnected
    case disconnecting(TunnelProtocol, ConnectionSpec)
    case connecting(Intent)
    /// The connected state is split across ``TunnelConfiguration`` (which is unlikely to change without user interaction),
    /// and `ResolvedDynamicConnectionData` which is the more transient/dynamic data.
    case connected(TunnelConfiguration, ResolvedDynamicConnectionData)

    @DebugDescription
    @CasePathable
    public enum Intent: Equatable, Sendable {
        case unresolved(ConnectionPreparationIntent)
        case resolved(ResolvedConnectionIntent)
    }

    /// Same as DynamicConnectionData, but the peerId string has been resolved to an actual server
    @DebugDescription
    public struct ResolvedDynamicConnectionData: Equatable, Sendable {
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
        connectionState: .resolving,
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
            ".localAgentNotice(\(error.errorCodeString))"
        case let .errorReported(error):
            ".errorReported(\(error))"
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

public enum LocalAgentTwoFactorAuthenticationError: FourCharCode, ProtonVPNError {
    public static let errorDomain = "LocalAgent2FAErrorDomain"

    /// The server requires a more recent 2FA, for an unspecified reason.
    case authenticationRequired = "LA2R"
    /// The server requires a more recent 2FA, 2FA validity has expired.
    /// This is more specific than `authenticationRequired` to give the user an explanation, but the behavior is
    /// exactly the same.
    case authenticationExpired = "LA2E"
    /// The server requires a more recent 2FA, as it’s a new connection or the client address has roamed.
    /// From the client perspective, this can be handled as `authenticationRequired` (if the client supports it),
    /// or ad-interim by asking the user to provide a 2FA via the browser.
    case authenticationLocationChanged = "LA2L"
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
        }
    }
}
