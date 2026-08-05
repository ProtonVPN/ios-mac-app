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

        @Shared(.userCountry) var userCountry: String?
        @Shared(.userIP) var userIP: String?
        @Shared(.userISP) var userISP: String?
        @Shared(.lastLocationRetrieval) var lastLocationRetrieval: Date?
    }

    public enum Action {
        /// Set up effects to request a location fetch every hour, or whenever app returns to foreground
        case listen
        case didBecomeActive(notification: Notification)
        /// Fetch user location if we haven't recently done so already
        case fetchUserLocation
        /// Fetch user location immediately, unless VPN is active
        case userLocationFetchStarted
        case userLocationFetchFinished(Result<UserLocation, LocationFetchFailure>)
        case tearDown
        case delegate(Delegate)

        case connectionStateUpdate(ConnectionState)

        @CasePathable
        public enum Delegate {
            case userLocationChanged(UserLocation)
        }
    }

    private enum CancelID {
        case didBecomeActive
        case userLocationTimer
        case userLocation
        case watchConnectionState
    }

    private static let locationCooldownInterval: TimeInterval = .hours(1)

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
        interval: .seconds(Self.locationCooldownInterval)
    ) { send in
        send(.fetchUserLocation)
    }.cancellable(id: CancelID.userLocationTimer, cancelInFlight: true)

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    longLivingDidBecomeActiveEffect,
                    longLivingUserLocationTimerEffect,
                    longLivingConnectionStateEffect
                )

            case .fetchUserLocation:
                if let lastLocationRetrieval = state.lastLocationRetrieval {
                    let nextRetrievalDate = lastLocationRetrieval.addingTimeInterval(Self.locationCooldownInterval)
                    guard date.now >= nextRetrievalDate else {
                        return .send(.userLocationFetchFinished(.failure(.cooldown(nextRetrievalDate))))
                    }
                } // Nothing retrieved yet, so no cooldown to respect

                // The endpoint answers with the exit IP while a tunnel is up, so only the
                // disconnected state can tell us the user's own address. This is decided here rather
                // than inside the effect because a connected session that adopted a tunnel-reported
                // IP carries no cooldown (see `.connectionStateUpdate`), which brings every timer
                // tick and every foregrounding this far.
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

                let userIP = location.ip
                let lowercasedUserCountry = location.country.lowercased()
                // Refresh cooldown on every successful fetch, even if location is unchanged.
                // Otherwise, repeated triggers can bypass throttling once the initial cooldown passes.
                state.$lastLocationRetrieval.withLock { $0 = date.now }

                if userIP == state.userIP, lowercasedUserCountry == state.userCountry?.lowercased() {
                    log.debug("User Location unchanged from last fetch", category: .api)
                    return .none
                }

                log.debug("Updating user location defaults", category: .persistence)
                state.$userCountry.withLock { $0 = lowercasedUserCountry }
                state.$userISP.withLock { $0 = location.isp }
                state.$userIP.withLock { $0 = userIP }
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
                return .send(.fetchUserLocation)

            case .tearDown:
                return .merge(
                    .cancel(id: CancelID.userLocation),
                    .cancel(id: CancelID.didBecomeActive),
                    .cancel(id: CancelID.userLocationTimer),
                    .cancel(id: CancelID.watchConnectionState)
                )

            case .delegate:
                return .none

            case let .connectionStateUpdate(connectionState):
                if connectionState.is(\.disconnected) {
                    return .send(.fetchUserLocation)
                }
                // Secure Core puts a second hop between the device and the server running the local
                // agent, so what that server observes is the entry node rather than the user. Leave
                // the stored values alone for those sessions: the endpoint fetch performed on the
                // next disconnection remains the only source we can trust there.
                guard connectionState.resolvedServer?.logical.feature.contains(.secureCore) != true else {
                    return .none
                }

                // `/vpn/location` reports the exit IP while the tunnel is up, so the fetch above is
                // skipped and the stored values would otherwise keep whatever the last disconnected
                // fetch saw — stale as soon as the underlying network changes, or as soon as the app
                // is relaunched into an already-connected session. ProTUN's local agent reports the
                // address the server observes for us, which is exactly the "my IP" we want to show.
                guard let proTUNData = connectionState.proTUNConnectionData,
                      let userIP = proTUNData.userIP,
                      userIP != state.userIP
                else {
                    return .none
                }

                log.debug("Updating user location defaults from tunnel-reported data", category: .connection)
                state.$userIP.withLock { $0 = userIP }
                if let userISP = proTUNData.userISP {
                    state.$userISP.withLock { $0 = userISP }
                }
                // The stored country was resolved from the address the previous fetch saw, and the
                // tunnel doesn't report one to pair with this IP. Clearing the cooldown makes the
                // fetch performed on the next disconnection re-establish a consistent country/IP pair
                // instead of leaving the old country next to the new address.
                state.$lastLocationRetrieval.withLock { $0 = nil }
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
