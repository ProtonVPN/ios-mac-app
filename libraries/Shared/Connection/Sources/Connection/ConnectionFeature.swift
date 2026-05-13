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
    @Dependency(\.connectionFeatureProvider) private var connectionFeatureProvider

    public init() {}

    public struct State: Equatable, Sendable {
        @SharedReader(.userTier) public var userTier: Int?
        var connectionState: ConnectionState
        var shouldRegisterServerChangeOnConnection: Bool // TODO: post connection events that some other component can hook into to do this
        var core: CoreConnectionFeature.State

        package init(
            connectionState: ConnectionState,
            shouldRegisterServerChangeOnConnection: Bool,
            core: CoreConnectionFeature.State
        ) {
            self.connectionState = connectionState
            self.shouldRegisterServerChangeOnConnection = shouldRegisterServerChangeOnConnection
            self.core = core
        }
    }

    @DebugDescription
    public enum Action: Sendable {
        case prepare(ConnectionPreparationIntent)
        case finishedPreparing(Result<ServerConnectionIntent, IntentResolutionError>)
        case core(CoreConnectionFeature.Action)
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
            case applySettings(Set<ConnectionFeatureChange.AgentFeature>)
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
        }
    }

    private enum CancelID {
        case preparation
        case connectionTimeout
        case observation
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.core, action: \.core) { CoreConnectionFeature() } // Firstly, process internal connection events
        Reduce { state, action in
            switch action {
            case .input(.onLaunch):
                return .merge(
                    .merge(
                        .send(.core(.startObserving)),
                        // logout or guest→authenticated transition
                        .listen(to: sessionChangeNotifier.stream()) { _ in .input(.onSessionChange) }
                    ).cancellable(id: CancelID.observation, cancelInFlight: true),
                    .run { _ in
                        @Dependency(\.localAgent) var localAgentClient
                        let features = connectionFeatureProvider.connectionFeatures()
                        localAgentClient.writeSettings { $0 = IPCLASettingsPayload(features) }
                    }
                )

            case .stopObserving:
                return .merge(.send(.core(.stopObserving)), .cancel(id: CancelID.observation))

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

            case let .input(.applySettings(agentFeatures)):
                return .run { _ in
                    @Dependency(\.localAgent) var localAgentClient
                    try localAgentClient.postRequestToExtension(.setFeatures(agentFeatures))
                }

            case .input(.disconnect):
                return .merge(
                    .cancel(id: CancelID.preparation),
                    .send(.core(.disconnect(.userIntent)))
                )

            case .input(.onLogout):
                return .merge(.send(.stopObserving), .send(.core(.handleLogout)))

            case .input(.onSessionChange):
                return .send(.core(.handleLogout))

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
                state.connectionState = ConnectionState.connecting(.resolved(resolvedIntent, resolvedIntent.server))
                return .send(.core(.connect(resolvedIntent)))

            case let .finishedPreparing(.failure(error)):
                log.error("Failed to preparing connection with error: \(error)")
                // Revert state to actual tunnel state
                state.connectionState = ConnectionState(tunnel: state.core.tunnel)
                return .send(.delegate(.connectionFailed(.preparation(.intentResolution(error)))))

            case let .core(.delegate(.stateChanged(.disconnected(.some(error))))):
                state.connectionState = .disconnected
                return .send(.delegate(.connectionFailed(.tunnel(error))))

            case let .core(.delegate(.stateChanged(.connected(protocolConfiguration, details)))):
                if state.shouldRegisterServerChangeOnConnection {
                    guard let date = details?.connectionDate else {
                        // TODO: error handling
                        return .none
                    }
                    @Dependency(\.serverChangeAuthorizer) var authorizer
                    authorizer.registerServerChange(connectedAt: date)
                }
                state.connectionState = ConnectionState(tunnel: state.core.tunnel)
                return .none

            case let .core(.delegate(.stateChanged(newState))):
                state.connectionState = ConnectionState(tunnel: newState)
                return .none

            case let .core(.delegate(.error(connectionError))):
                return .send(.delegate(.connectionFailed(connectionError)))

            case let .core(.delegate(.featuresChanged(features))):
                return .run { _ in
                    connectionFeatureProvider.setConnectionFeatures(features)
                }

            case .core:
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
    case disconnecting(ServerConnectionIntent, Server)
    case connecting(Intent)
    case connected(ServerConnectionIntent, Server, Date, ConnectionDetailsMessage?)

    @DebugDescription
    @CasePathable
    public enum Intent: Equatable, Sendable {
        case unresolved(ConnectionPreparationIntent)
        case resolved(ServerConnectionIntent, Server)
    }
}

public extension ConnectionFeature.State {
    static let initialState = ConnectionFeature.State(
        connectionState: .resolving,
        shouldRegisterServerChangeOnConnection: false,
        core: .initialCoreConnectionState
    )
}

extension ConnectionFeature.Action: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .prepare(intent):
            ".prepare(\(intent))"
        case let .finishedPreparing(result):
            ".finishedPreparing(\(result))"
        case let .core(action):
            ".core(\(action.debugDescription))"
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
        case let .connected(intent, server, date, message):
            ".connected(\(intent), \(server), \(date), \(String(describing: message)))"
        }
    }
}

extension ConnectionState.Intent: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .unresolved(intent):
            ".unresolved(\(intent))"
        case let .resolved(intent, server):
            ".resolved(\(intent), \(server))"
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
    init(tunnel: ExtensionFeature.State) {
        switch tunnel {
        case .unknown:
            self = .resolving

        case .connecting:
            // TODO: Expand connecting state with information from provider config/mmap
            self = .resolving

        case .reasserting:
            // TODO: Expand connecting state with information from provider config/mmap
            self = .resolving

        case let .connected(protocolConfig, data):
            // TODO: error handling
            @Dependency(\.serverIdentifier) var identifier
            guard let data, let server = identifier.fullServerInfo(data.serverID) else {
                self = .resolving
                return
            }
            // TODO: store and retrieve this data on the protocol configuration, OR retrieve via mmap
            let spec = ConnectionSpec(location: .exact(.paid, logicalID: server.logical.id, number: nil, subregion: nil, regionCode: server.logical.exitCountryCode), features: [])
            let features: TunnelFeatures
            #if os(tvOS)
                features = .tvFeatures
            #else
                features = .init(killSwitch: false, excludeLocalNetworks: false)
            #endif
            let fakeIntent = ServerConnectionIntent(
                spec: spec,
                server: server,
                protocolConfiguration: .wireGuard(.init(backend: .proTUN, transport: .udp, features: features)),
                features: .init(netshield: .level2, vpnAccelerator: true, bouncing: nil, natType: .moderateNAT, safeMode: nil, portForwarding: nil)
            )
            self = .connected(fakeIntent, server, .now, nil)

        case .disconnecting:
            // TODO: Expand connecting state with information from provider config/mmap
            self = .resolving

        case let .disconnected(error):
            self = .disconnected

        case .invalid:
            self = .disconnected
        }
    }
}
