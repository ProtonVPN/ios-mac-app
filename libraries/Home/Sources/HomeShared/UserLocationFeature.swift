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

import Foundation

import ComposableArchitecture

import Domain
import enum Connection.ConnectionState
import VPNAppCore
import Ergonomics

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
        @Shared(.lastLocationRetrieval) var lastLocationRetrieval: Date?
    }

    @CasePathable
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

        @CasePathable
        public enum Delegate {
            case userLocationChanged(UserLocation)
        }
    }

    private enum CancelID {
        case didBecomeActive
        case userLocationTimer
        case userLocation
    }

    private static let locationCooldownInterval: TimeInterval = .hours(1)

    private let longLivingDidBecomeActiveEffect: Effect<Action> = .publisher {
        NotificationCenter.default
            .publisher(for: didBecomeActiveNotification)
            .debounce(for: 1.0, scheduler: UIScheduler.shared)
            .receive(on: UIScheduler.shared)
            .map(Action.didBecomeActive)
    }.cancellable(id: CancelID.didBecomeActive)

    private let longLivingUserLocationTimerEffect: Effect<Action> = .timer(
        interval: .seconds(Self.locationCooldownInterval)
    ) { send in
        send(.fetchUserLocation)
    }.cancellable(id: CancelID.userLocationTimer)

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    .send(.fetchUserLocation),
                    longLivingDidBecomeActiveEffect,
                    longLivingUserLocationTimerEffect
                )

            case .fetchUserLocation:
                guard let lastLocationRetrieval = state.lastLocationRetrieval else {
                    // We've not fetched user location yet, let's do it immediately
                    return .send(.userLocationFetchStarted)
                }

                let nextRetrievalDate = lastLocationRetrieval.addingTimeInterval(Self.locationCooldownInterval)
                let isLocationCooldownPassed = date.now >= nextRetrievalDate
                if isLocationCooldownPassed {
                    return .send(.userLocationFetchStarted)
                } else {
                    return .send(.userLocationFetchFinished(.failure(.cooldown(nextRetrievalDate))))
                }

            case .userLocationFetchStarted:
                let connectionState = state.connectionState
                return .run { send in
                    // UserLocation cannot be fetched while connected
                    guard connectionState.is(\.disconnected) else {
                        return await send(.userLocationFetchFinished(.failure(.incorrectVPNState(connectionState))))
                    }

                    log.info("Explicit User Location retrieval attempt", category: .api)
                    @Dependency(\.locationClient) var locationClient
                    let result = await Result { try await locationClient.fetchLocation() }
                        .mapError { LocationFetchFailure.network($0) }
                    await send(.userLocationFetchFinished(result))
                }.cancellable(id: CancelID.userLocation, cancelInFlight: true)

            case let .userLocationFetchFinished(.success(location)):
                let userIP = location.ip
                let lowercasedUserCountry = location.country.lowercased()

                if userIP == state.userIP, lowercasedUserCountry == state.userCountry?.lowercased() {
                    log.debug("User Location unchanged from last fetch", category: .api)
                    return .none
                }

                log.debug("Updating user location defaults", category: .persistence)
                state.$userCountry.withLock { $0 = lowercasedUserCountry }
                state.$userIP.withLock { $0 = userIP }
                state.$lastLocationRetrieval.withLock { $0 = date.now }
                return .send(.delegate(.userLocationChanged(location)))

            case let .userLocationFetchFinished(.failure(error)):
                log.error("User location request failed", category: .api, metadata: ["error": "\(error)"])
                return .none

            case .didBecomeActive:
                return .send(.fetchUserLocation)

            case .tearDown:
                return .merge(
                    .cancel(id: CancelID.userLocation),
                    .cancel(id: CancelID.didBecomeActive),
                    .cancel(id: CancelID.userLocationTimer)
                )

            case .delegate:
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
