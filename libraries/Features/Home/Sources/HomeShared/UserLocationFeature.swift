//
//  Created on 06/02/2025.
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

import ComposableArchitecture
import enum Connection.ConnectionState
import Domain
import Ergonomics
import Foundation
import NetworkingErgonomics
import VPNAppCore

#if canImport(UIKit)
    import class UIKit.UIApplication
#elseif canImport(AppKit)
    import class AppKit.NSApplication
#endif

let didBecomeActiveNotification: NSNotification.Name = {
    #if canImport(UIKit)
        return UIApplication.didBecomeActiveNotification
    #elseif canImport(AppKit)
        return NSApplication.didBecomeActiveNotification
    #else
        fatalError("Unsupported platform")
    #endif
}()

@Reducer
public struct UserLocationFeature {
    @Dependency(\.date) var date

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.connectionState) var connectionState: ConnectionState
        @SharedReader(.userLocation) var userLocation: StoredUserLocation?
    }

    public enum Action {
        /// Set up effects to request a location fetch every hour, whenever the app returns to the
        /// foreground, and whenever the device attaches to a different network
        case listen
        case didBecomeActive(notification: Notification)
        /// Fetch user location unless the last fetch is younger than the trigger's cooldown
        case fetchUserLocation(FetchTrigger)
        /// Fetch user location immediately, unless VPN is active
        case userLocationFetchStarted
        case userLocationFetchFinished(Result<UserLocation, LocationFetchFailure>)
        /// The device attached to a different network, so the stored address describes the previous one
        case networkPathChanged
        case tearDown
        case delegate(Delegate)

        case connectionStateUpdate(ConnectionState)

        @CasePathable
        public enum Delegate {
            case userLocationChanged(UserLocation)
        }
    }

    /// What prompted a fetch, and with it how stale the stored location has to be for the request to
    /// be worth making.
    public enum FetchTrigger: Equatable, Sendable {
        /// The interval timer, the app coming to the foreground, or the tunnel going down. The stored
        /// address is probably still correct, so the full interval applies.
        case routine
        /// The device attached to a different network, which invalidates the stored address outright.
        /// Only a short floor applies, to keep a flapping interface from hammering the endpoint.
        case networkChange

        var cooldown: TimeInterval {
            switch self {
            case .routine: .hours(1)
            case .networkChange: .minutes(1)
            }
        }
    }

    private enum CancelID {
        case didBecomeActive
        case userLocationTimer
        case userLocation
        case watchConnectionState
        case watchNetworkPath
    }

    private let longLivingConnectionStateEffect: Effect<Action> = .publisher {
        @SharedReader(.connectionState) var connectionState
        return $connectionState.publisher
            .removeDuplicates()
            .map { state in Action.connectionStateUpdate(state) }
    }.cancellable(id: CancelID.watchConnectionState)

    private let longLivingDidBecomeActiveEffect: Effect<Action> = .publisher {
        NotificationCenter.default
            .publisher(for: didBecomeActiveNotification)
            .debounce(for: 1.0, scheduler: UIScheduler.shared)
            .receive(on: UIScheduler.shared)
            .map(Action.didBecomeActive)
    }.cancellable(id: CancelID.didBecomeActive, cancelInFlight: true)

    private let longLivingUserLocationTimerEffect: Effect<Action> = .timer(
        interval: .seconds(FetchTrigger.routine.cooldown)
    ) { send in
        send(.fetchUserLocation(.routine))
    }.cancellable(id: CancelID.userLocationTimer, cancelInFlight: true)

    private let longLivingNetworkPathEffect: Effect<Action> = .run { send in
        @Dependency(\.pathMonitor) var pathMonitor

        let paths = pathMonitor.subscribe()

        // The monitor drops repeated paths
        for await path in paths where path.isUsable {
            await send(.networkPathChanged)
        }
    }.cancellable(id: CancelID.watchNetworkPath, cancelInFlight: true)

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    longLivingDidBecomeActiveEffect,
                    longLivingUserLocationTimerEffect,
                    longLivingConnectionStateEffect,
                    longLivingNetworkPathEffect
                )

            case let .fetchUserLocation(trigger):
                // A tunnel-reported address arrives without a country, so the pair on screen is only
                // as good as the country the previous measurement left behind: measure again at the
                // first opportunity rather than waiting out the interval.
                if let stored = state.userLocation, stored.isCountryVerified {
                    let nextRetrievalDate = stored.measuredAt.addingTimeInterval(trigger.cooldown)
                    guard date.now >= nextRetrievalDate else {
                        return .send(.userLocationFetchFinished(.failure(.cooldown(nextRetrievalDate))))
                    }
                } // Nothing measured yet, or measured against an address we have since replaced

                // The endpoint will fail while a tunnel is up, we need a disconnected state.
                guard state.connectionState.is(\.disconnected) else {
                    return .merge(
                        // A request that was already in flight when the tunnel came up would answer
                        // with the exit IP.
                        .cancel(id: CancelID.userLocation),
                        .send(.userLocationFetchFinished(.failure(.incorrectVPNState(state.connectionState))))
                    )
                }
                return .send(.userLocationFetchStarted)

            case .userLocationFetchStarted:
                return .run { send in
                    log.info("Explicit User Location retrieval attempt", category: .api)
                    @Dependency(\.locationClient) var locationClient
                    let result = await Result { try await locationClient.fetchLocation() }
                        .mapError { LocationFetchFailure.network($0) }
                    await send(.userLocationFetchFinished(result))
                }.cancellable(id: CancelID.userLocation, cancelInFlight: true)

            case let .userLocationFetchFinished(.success(location)):
                // A request can only start while disconnected, but the tunnel may have come up while
                // it was in flight — in which case the endpoint answered with the exit IP, and the
                // disconnection this connection ends with triggers a fresh fetch anyway.
                guard state.connectionState.is(\.disconnected) else {
                    log.debug("Discarding user location measured across a connection", category: .api)
                    return .none
                }

                let previous = state.userLocation
                // Recorded on every successful fetch, even when the location is unchanged: the
                // timestamp is what throttles the next trigger.
                @Shared(.userLocation) var userLocation
                $userLocation.recordMeasured(location)

                guard location != previous?.location else {
                    log.debug("User Location unchanged from last fetch", category: .api)
                    return .none
                }
                return .send(.delegate(.userLocationChanged(location)))

            case let .userLocationFetchFinished(.failure(error)):
                switch error {
                case .cooldown, .incorrectVPNState:
                    // Routine outcomes rather than failures: throttling, or a tunnel being up.
                    log.debug("User location request skipped", category: .api, metadata: ["reason": "\(error)"])
                case .network:
                    log.error("User location request failed", category: .api, metadata: ["error": "\(error)"])
                }
                return .none

            case .didBecomeActive:
                return .send(.fetchUserLocation(.routine))

            case .networkPathChanged:
                // Whatever is stored describes the network the device just left.
                log.debug("Network path changed, refreshing user location", category: .api)
                return .send(.fetchUserLocation(.networkChange))

            case .tearDown:
                return .merge(
                    .cancel(id: CancelID.userLocation),
                    .cancel(id: CancelID.didBecomeActive),
                    .cancel(id: CancelID.userLocationTimer),
                    .cancel(id: CancelID.watchConnectionState),
                    .cancel(id: CancelID.watchNetworkPath)
                )

            case .delegate:
                return .none

            case let .connectionStateUpdate(connectionState):
                if connectionState.is(\.disconnected) {
                    return .send(.fetchUserLocation(.routine))
                }
                // Secure Core puts a second hop between the device and the server running the local
                // agent, so what that server observes is the entry node rather than the user. Leave
                // the stored values alone for those sessions: the endpoint fetch performed on the
                // next disconnection remains the only source we can trust there.
                guard connectionState.resolvedServer?.logical.feature.contains(.secureCore) != true else {
                    return .none
                }

                // `/vpn/location` will fail if the tunnel is up, so the fetch above is
                // skipped and the stored values would otherwise keep whatever the last disconnected
                // fetch saw — stale as soon as the underlying network changes, or as soon as the app
                // is relaunched into an already-connected session. ProTUN's local agent reports the
                // address the server observes for us, which is exactly the "my IP" we want to show.
                guard let proTUNData = connectionState.proTUNConnectionData,
                      let userIP = proTUNData.userIP,
                      userIP != state.userLocation?.location.ip
                else {
                    return .none
                }

                log.debug("Updating user location from tunnel-reported data", category: .connection)
                // Recorded as a tunnel report, which marks the country that comes with it as
                // belonging to the address this one replaced — the fetch on the next disconnection
                // re-establishes a consistent pair.
                @Shared(.userLocation) var userLocation
                $userLocation.recordTunnelReported(ip: userIP, isp: proTUNData.userISP)
                return .none
            }
        }
    }

    @CasePathable
    public enum LocationFetchFailure: Error {
        /// User location was already recently fetched
        case cooldown(Date)
        /// User location can only be reliably fetched in the `disconnected` state
        case incorrectVPNState(ConnectionState)
        /// Network request failed
        case network(any Error)
    }
}
