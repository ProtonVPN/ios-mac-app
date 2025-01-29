//
//  Created on 25/09/2024.
//
//  Copyright (c) 2024 Proton AG
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
import CommonNetworking
import Foundation
import Domain
import VPNAppCore

@Reducer
public struct SharedPropertiesFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.userCountry) public var userCountry: String?
        @Shared(.userIP) public var userIP: String?
        @Shared(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus
    }

    @CasePathable
    public enum Action {
        case listen
        case userLocationChange(location: UserLocation?)
        case newConnectionStatus(VPNConnectionStatus)
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    private let initialUserLocationEffect: Effect<Action> = .run { send in
        @Dependency(\.locationClient) var client
        let initialLocation = try await client.fetchLocation()
        await send(.userLocationChange(location: initialLocation))
    }

    private let longLivingUserLocationEffect: Effect<Action> = .publisher {
        NotificationCenter.default
            .publisher(for: .userIpNotification)
            .map { $0.object as? Domain.UserLocation }
            .receive(on: UIScheduler.shared)
            .map(Action.userLocationChange)
    }

    private let longLivingConnectionStatusEffect: Effect<Action> = .run { @MainActor send in
        let stream = Dependency(\.connectionBridge)
            .wrappedValue
            .statusStream
            .map { Action.newConnectionStatus($0) }

        for await value in stream {
            send(value)
        }
    }
    .cancellable(id: CancelId.watchConnectionStatus)

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    initialUserLocationEffect,
                    longLivingUserLocationEffect,
                    longLivingConnectionStatusEffect
                )

            case .userLocationChange(let location):
                // Try preventing the whole map view because of possibly missing userLocation
                // User location is changing very rarely and we can expect it prevails between app launches and even switching of users.
                if let userCountry = location?.country.lowercased(),
                   let userIP = location?.ip ?? state.userIP {
                    state.$userCountry.withLock { $0 = userCountry }
                    state.$userIP.withLock { $0 = userIP }
                }
                return .none

            case .newConnectionStatus(let connectionStatus):
                state.$vpnConnectionStatus.withLock { $0 = connectionStatus }
                return .none
            }
        }
    }
}
