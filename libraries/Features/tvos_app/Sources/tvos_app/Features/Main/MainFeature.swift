//
//  Created on 25/04/2024.
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

import Connection
import Domain
import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import Foundation
import Persistence

@Reducer
struct MainFeature {
    @Dependency(\.serverRepository) private var repository

    enum Tab {
        case home
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var currentTab: Tab = .home
        var homeLoading = HomeLoadingFeature.State.loading
        var settings = SettingsFeature.State()

        @Shared(.connectionState) var connectionState: ConnectionState = .resolving
        @Shared(.userLocation) var userLocation: UserLocation?
        @Shared(.mainBackground) var mainBackground: MainBackground = .clear
    }

    enum Action {
        case selectTab(Tab)
        case homeLoading(HomeLoadingFeature.Action)
        case settings(SettingsFeature.Action)
        case signOut
        case launchConnection
        case connect(ConnectionPreparationIntent)
        case disconnect

        case userSelectedItem(ConnectableItem)

        case onAppear
        case updateUserLocation
        case connectDisconnectingIfNecessary(ConnectableItem)

        case connectionStateUpdated(ConnectionState)
        case observeConnectionState
    }

    private enum CancelId {
        case connectionState
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.homeLoading, action: \.homeLoading) { HomeLoadingFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.launchConnection),
                    .send(.observeConnectionState)
                )

            case .observeConnectionState:
                return .publisher {
                    state.$connectionState.publisher
                        .receive(on: UIScheduler.shared)
                        .map(Action.connectionStateUpdated)
                }
                .cancellable(id: CancelId.connectionState)

            case let .connectionStateUpdated(connectionState):
                if case .home = state.currentTab {
                    state.$mainBackground.withLock { $0 = .init(connectionState: connectionState) }
                }
                if case .disconnected = connectionState {
                    return .send(.updateUserLocation)
                }
                return .none

            case let .selectTab(tab):
                state.currentTab = tab
                switch tab {
                case .home:
                    state.$mainBackground.withLock { $0 = .init(connectionState: state.connectionState) }
                    return .none
                case .settings:
                    return .send(.settings(.tabSelected))
                }

            case .launchConnection, .connect, .disconnect:
                // Parent AppFeature owns ConnectionFeature and handles these intent actions.
                return .none

            case .signOut:
                // Parent AppFeature owns logout sequencing.
                return .none

            case .settings(.alert(.presented(.signOut))):
                return .send(.signOut)

            case .settings:
                return .none

            case let .homeLoading(.loaded(.countryList(.selectItem(item)))):
                return .send(.userSelectedItem(item))

            case let .userSelectedItem(item):
                switch handleConnectionIntent(to: item, currentConnectionState: state.connectionState) {
                case .connect:
                    return .send(.connectDisconnectingIfNecessary(item))
                case .disconnect:
                    return .send(.disconnect)
                }

            case let .homeLoading(.loaded(.protectionStatus(.delegate(action)))):
                switch action {
                case .userClickedDisconnect:
                    return .send(.disconnect)
                case .userClickedCancel:
                    return .send(.disconnect)
                case .userClickedConnect:
                    return .send(.connectDisconnectingIfNecessary(CountryListItem.fastest.connectableItem))
                }

            case .homeLoading:
                return .none

            case let .connectDisconnectingIfNecessary(connectable):
                return .run { send in
                    let intent = connectionPreparationIntent(
                        connectionSpec: connectable.connectionSpec
                    )
                    return await send(.connect(intent))
                }

            case .updateUserLocation:
                if state.userLocation == nil {
                    return .run { _ in
                        @Dependency(\.userLocationService) var userLocationService
                        try? await userLocationService.updateUserLocation()
                    }
                }
                return .none
            }
        }
    }

    private func connectionPreparationIntent(connectionSpec: ConnectionSpec) -> ConnectionPreparationIntent {
        ConnectionPreparationIntent(
            spec: connectionSpec,
            acceptableProtocols: [.wireGuardUDP]
        )
    }

    private func handleConnectionIntent(
        to target: ConnectableItem,
        currentConnectionState: ConnectionState
    ) -> ConnectionStrategy {
        let targetLocation = target.connectionSpec.location
        guard let currentLocation = activeLocation(from: currentConnectionState) else {
            // If we're not already connecting/connected, we can just connect to the selected country
            return .connect
        }
        if targetLocation == currentLocation {
            // If the selected location is the same as the connecting/connected one, disconnect
            return .disconnect
        }
        if case let .country(targetCountryCode, _) = targetLocation,
           case let .city(_, currentCountryCode, _) = currentLocation {
            // If we choose a country, but we are already connected to a city in that country, disconnect
            return targetCountryCode == currentCountryCode ? .disconnect : .connect
        }

        // Otherwise, proceed with connection to the selected country
        return .connect
    }

    private func activeLocation(from connectionState: ConnectionState) -> ConnectionSpec.Location? {
        switch connectionState {
        case let .connected(intent, _, _, _):
            intent.spec.location
        case let .connecting(.unresolved(intent)):
            intent.spec.location
        case let .connecting(.resolved(intent, _)):
            intent.spec.location
        case .disconnected, .disconnecting, .resolving:
            nil
        }
    }

    enum ConnectionStrategy {
        case disconnect
        case connect
    }
}

private extension ServerGroupInfo.Kind {
    var code: String? {
        switch self {
        case let .city(_, code):
            code
        case let .state(_, code):
            code
        case let .country(code):
            code
        case let .gateway(name):
            name
        }
    }
}

enum ServerResolutionError: Error {
    case noActiveServers(String)
    case serverHasNoEndpoints
}

private extension ServerGroupInfo.Kind {
    var selectedItem: (code: String, cityName: String?) {
        switch self {
        case let .city(name, code):
            return (code, name)
        case let .state(name, code):
            return (code, name)
        case let .country(code):
            return (code, nil)
        case let .gateway(name):
            log.assertionFailure("Unexpected ServerGroupInfo kind: \(self)")
            return (name, nil)
        }
    }
}
