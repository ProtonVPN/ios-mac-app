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
    return NSApplicationDidBecomeActiveNotification
#else
    fatalError("Unsupported platform")
#endif
}()

@Reducer
public struct UserLocationFeature {
    @ObservableState
    public struct State: Equatable {
        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

        @Shared(.userCountry) var userCountry: String?
        @Shared(.userIP) var userIP: String?
        @Shared(.lastLocationRetrieval) var lastLocationRetrieval: Date?

        public init(
            userCountry: String? = nil,
            userIP: String? = nil,
            lastLocationRetrieval: Date? = nil
        ) {
            self.$userCountry.withLock { $0 = userCountry }
            self.$userIP.withLock { $0 = userIP }
            self.$lastLocationRetrieval.withLock { $0 = lastLocationRetrieval }
        }
    }

    @CasePathable
    public enum Action {
        case listen
        case fetchUserLocation
        case didBecomeActive(notification: Notification)
        case userLocationChange(location: UserLocation?)
        case tearDown
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
                log.info("Explicit User Location retrieval attempt")
                return .run { send in
                    @Dependency(\.locationClient) var locationClient
                    let location = try await locationClient.fetchLocation()
                    await send(.userLocationChange(location: location))
                } catch: { error, _ in
                    log.error("Initial User location retrieval failed: \(error.localizedDescription)")
                }

            case .userLocationChange(let location):
                // Try preventing the whole map view because of possibly missing userLocation
                // User location is changing very rarely and we can expect it prevails between app launches and even switching of users.
                if let userCountry = location?.country.lowercased(), let userIP = location?.ip ?? state.userIP {
                    log.info("User Location did change, updating defaults")
                    state.$userCountry.withLock { $0 = userCountry }
                    state.$userIP.withLock { $0 = userIP }
                    state.$lastLocationRetrieval.withLock { $0 = Date.now }
                }
                return .none

            case .didBecomeActive(_):
                // No need to query the fetch userLocation if we're connected
                guard !state.vpnConnectionStatus.is(\.connected) else { return .none }
                let lastLocationRetrievalInterval = abs((state.lastLocationRetrieval ?? .now).timeIntervalSinceNow)
                let moreThanOneHour = lastLocationRetrievalInterval >= Self.locationCooldownInterval
                return moreThanOneHour ? .send(.fetchUserLocation) : .none

            case .tearDown:
                return .merge(
                    .cancel(id: CancelID.didBecomeActive),
                    .cancel(id: CancelID.userLocationTimer)
                )
            }
        }
    }
}
