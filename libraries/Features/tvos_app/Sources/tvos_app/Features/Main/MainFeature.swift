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
import ModalsServices
import Persistence

@Reducer
struct MainFeature {
    @Dependency(\.serverRepository) private var repository
    @Dependency(\.alertService) private var alertService

    enum Tab {
        case home
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var currentTab: Tab = .home
        var homeLoading = HomeLoadingFeature.State.loading
        var settings = SettingsFeature.State()
        var connection = ConnectionFeature.State.initialState

        @Shared(.connectionState) var connectionState: ConnectionState = .resolving
        @Shared(.userLocation) var userLocation: UserLocation?
        @Shared(.mainBackground) var mainBackground: MainBackground = .clear
    }

    enum Action {
        case selectTab(Tab)
        case homeLoading(HomeLoadingFeature.Action)
        case settings(SettingsFeature.Action)

        case onAppear
        case onLogout
        case updateUserLocation

        case connection(ConnectionFeature.Action)
        case connectDisconnectingIfNecessary(countryCode: String, cityName: String?)

        case errorOccurred(Error)

        case connectionStateUpdated(ConnectionState)
        case observeConnectionState
    }

    private enum CancelId {
        case connectionState
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.connection, action: \.connection) { ConnectionFeature() }
        Scope(state: \.homeLoading, action: \.homeLoading) { HomeLoadingFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.connection(.input(.onLaunch))),
                    .send(.observeConnectionState)
                )

            case .onLogout:
                return .send(.connection(.input(.onLogout)))

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

            case .settings:
                return .none

            case let .homeLoading(.loaded(.countryList(.selectItem(kind)))):
                let (code, cityName) = kind.selectedItem
                switch handleConnectionIntent(to: code, currentConnectionState: state.connectionState) {
                case .connect:
                    return .send(.connectDisconnectingIfNecessary(countryCode: code, cityName: cityName))
                case .disconnect:
                    return .send(.connection(.input(.disconnect)))
                }

            case let .homeLoading(.loaded(.protectionStatus(.delegate(action)))):
                switch action {
                case .userClickedDisconnect:
                    return .send(.connection(.input(.disconnect)))
                case .userClickedCancel:
                    return .send(.connection(.input(.disconnect)))
                case .userClickedConnect:
                    return .send(.connectDisconnectingIfNecessary(countryCode: "Fastest", cityName: nil))
                }

            case .homeLoading:
                return .none

            case let .connectDisconnectingIfNecessary(countryCode, cityName):
                return .run { send in
                    let intent = connectionPreparationIntent(code: countryCode, cityName: cityName)
                    return await send(.connection(.input(.connect(intent))))
                }

            case .updateUserLocation:
                if state.userLocation == nil {
                    return .run { _ in
                        @Dependency(\.userLocationService) var userLocationService
                        try? await userLocationService.updateUserLocation()
                    }
                }
                return .none

            case let .connection(.delegate(.stateChanged(connectionState))):
                state.$connectionState.withLock { $0 = connectionState }
                if case .disconnected = connectionState {
                    return .send(.updateUserLocation)
                }
                return .none

            case let .connection(.delegate(.connectionFailed(error))):
                return .send(.errorOccurred(error))

            case .connection:
                return .none

            case let .errorOccurred(error):
                return .run { _ in await alertService.feed(error) }
            }
        }
    }

    private func connectionPreparationIntent(code: String, cityName: String?) -> ConnectionPreparationIntent {
        let location: ConnectionSpec.Location = if code == "Fastest" {
            .fastest
        } else if let cityName {
            .city(name: cityName, code: code)
        } else {
            .country(code: code)
        }

        return ConnectionPreparationIntent(
            spec: ConnectionSpec(
                location: location,
                features: [.streaming]
            ),
            acceptableProtocols: [.wireGuardUDP]
        )
    }

    private func handleConnectionIntent(
        to targetCountryCode: String,
        currentConnectionState: ConnectionState
    ) -> ConnectionStrategy {
        guard let activeCountryCode = activeCountryCode(from: currentConnectionState) else {
            // If we're not already connecting/connected, we can just connect to the selected country
            return .connect
        }
        if targetCountryCode == activeCountryCode {
            // If the selected country is the same as the connecting/connected one, disconnect
            return .disconnect
        } else {
            // Otherwise, proceed with connection to the selected country
            return .connect
        }
    }

    private func activeCountryCode(from connectionState: ConnectionState) -> String? {
        if case let .connected(_, server, _, _) = connectionState {
            return server.logical.exitCountryCode
        }
        if case let .connecting(.unresolved(intent)) = connectionState {
            return intent.spec.countryCode
        }
        if case let .connecting(.resolved(_, server)) = connectionState {
            return server.logical.exitCountryCode
        }
        return nil
    }

    enum ConnectionIntent {
        case country(String)
        case server(Server)
    }

    enum ConnectionStrategy {
        case disconnect
        case connect
    }
}

enum ServerResolutionError: Error {
    case noActiveServers(String)
    case serverHasNoEndpoints
}

private extension ServerGroupInfo.Kind {
    var selectedItem: (code: String, cityName: String?) {
        switch self {
        case let .city(code, cityName):
            (code, cityName)
        case let .country(code):
            (code, nil)
        case let .gateway(name):
            // not supported
            (name, nil)
        }
    }
}
