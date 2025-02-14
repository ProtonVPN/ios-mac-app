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
import ProtonCoreFeatureFlags
import CommonNetworking
import Foundation
import Domain
import VPNAppCore

@Reducer
public struct SharedPropertiesFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.vpnConnectionStatus)
        var vpnConnectionStatus: VPNConnectionStatus

        var userLocation: UserLocationFeature.State = .init()
    }

    @CasePathable
    public enum Action {
        case listen
        case userLocation(UserLocationFeature.Action)
        case newConnectionStatus(VPNConnectionStatus)
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    private static let connectionStatusStream: AsyncStream<VPNConnectionStatus> = {
        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.useConnectionFeature) {
            return Dependency(\.connectionBridge).wrappedValue.statusStream()
        } else {
            return Dependency(\.vpnConnectionStatusPublisher).wrappedValue()
        }
    }()

    private let longLivingConnectionStatusEffect: Effect<Action> = .run { @MainActor send in
        if !FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.useConnectionFeature) {
            // Legacy connection status stream does not yield an initial value
            // Let's manually send resolving since this is always the initial connection state at app launch
            send(.newConnectionStatus(.resolving(nil, nil)))
        }

        let actionStream = Self.connectionStatusStream.map { Action.newConnectionStatus($0) }

        for await value in actionStream {
            send(value)
        }
    }
    .cancellable(id: CancelId.watchConnectionStatus)

    public var body: some Reducer<State, Action> {
        Scope(state: \.userLocation, action: \.userLocation) {
            UserLocationFeature()
        }
        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    .send(.userLocation(.listen)),
                    longLivingConnectionStatusEffect
                )

            case .userLocation(_):
                return .none

            case .newConnectionStatus(let newValue):
                let connectionStatus: VPNConnectionStatus
                if case .connecting = newValue, case .connected(let spec, let server) = state.vpnConnectionStatus {
                    // If we transition directly from connected to connecting, it's due to local agent disconnecting
                    // and needing to re-establish connection. Let's skip this state transition to avoid showing the
                    // connecting state despite us already being connected
                    connectionStatus = .resolving(spec, server)
                } else {
                    connectionStatus = newValue
                }
                state.$vpnConnectionStatus.withLock { $0 = connectionStatus }
                return .none
            }
        }
    }
}

#if DEBUG
import Combine

extension LocationClient {
    public static func jumping(every interval: TimeInterval = 1) -> some Publisher<UserLocation, Never> {
        Timer.publish(every: interval, on: .main, in: .default)
            .autoconnect()
            .map { _ in UserLocation.samples.randomElement()! }
    }
}
#endif
