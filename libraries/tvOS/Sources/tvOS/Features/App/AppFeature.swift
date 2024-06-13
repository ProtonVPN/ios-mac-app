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

import struct Domain.VPNConnectionFeatures
import CommonNetworking
import Connection
import Persistence

/// Some business logic requires communication between reducers. This is facilitated by the parent feature, which
/// listens to actions coming from one child, and sends the relevant action to the other child. This allows features to
/// function independently in completely separate modules.
///
/// For example, for the sign-in flow:
///
/// ```
/// AppFeature {
///     SessionNetworkingFeature,
///     SignInFeature,
///     MainFeature { ... }
/// }
/// ```
///
/// If `SignInFeature` is responsible for logging in the user. Once the user has been signed in, it can send an action
/// such as `signInFinished(credentials: AuthCredentials)`. This is a delegate action that isn't handled by the
/// `SignInFeature`, but is instead handled by the `AppFeature`, which passes  a `SessionNetworkingFeature` action.
///
/// The reverse of this flow is used for logging out, where a user action from the `MainFeature` is observed by the
/// `AppFeature`, at which it sends a `SessionNetworkingFeature.Action` which is handled by the `SessionNetworkingFeature`
@Reducer struct AppFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.appStorage("userDisplayName")) var userDisplayName: String?
        @Shared(.appStorage("userTier")) var userTier: Int?
        var main = MainFeature.State()
        var welcome = WelcomeFeature.State()

        /// Determines whether we show the `MainFeature` or `WelcomeFeature` (sign in flow)
        var networking: SessionNetworkingFeature.State = .unauthenticated(nil)
        var connection: ConnectionFeature.State = .init(tunnelState: .disconnected, localAgentState: .disconnected)
    }

    enum Action {
        case main(MainFeature.Action)
        case welcome(WelcomeFeature.Action)

        case networking(SessionNetworkingFeature.Action)
        case connection(ConnectionFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()._printChanges()
        }
        Scope(state: \.networking, action: \.networking) {
            SessionNetworkingFeature()
        }
        Scope(state: \.welcome, action: \.welcome) {
            WelcomeFeature()
        }
        Scope(state: \.main, action: \.main) {
            MainFeature()
        }
        Reduce { state, action in
            switch action {
            case .main(.settings(.alert(.presented(.signOut)))):
                // Send an action to inform SessionNetworkingFeature, which will clear keychains and acquire unauth session
                return .run { send in await send(.networking(.startLogout)) }

            case .main(.homeLoading(.loaded(.connect(.userClickedConnect(let item))))):
                guard let code = item?.code else {
                    log.error("Connection item is nil")
                    return .none
                }
                @Dependency(\.serverRepository) var repository
                let filters = code == "Fastest" ?  [] : [VPNServerFilter.kind(.country(code: code))]
                let server = repository.getFirstServer(filteredBy: filters, orderedBy: .fastest)!
                let features = VPNConnectionFeatures(netshield: .level1, vpnAccelerator: true, bouncing: "1", natType: .moderateNAT, safeMode: false)
                return .send(.connection(.connect(server, features)))

            case .main(.homeLoading(.loaded(.connect(.userClickedDisconnect)))):
                return .send(.connection(.disconnect))

            case .main:
                return .none

            case .welcome(.destination(.presented(.signIn(.signInFinished(.success(let credentials)))))):
                state.main.currentTab = .home
                return .run { send in await send(.networking(.forkedSessionAuthenticated(.success(credentials)))) }

            case .welcome(.destination(.presented(.signIn(.signInFinished(.failure))))):
                return .none

            case .welcome:
                return .none

            case .networking(.userTierRetrieved(let tier, _)):
                state.userTier = tier
                return .none

            case .networking(.userDisplayNameRetrieved(let name)):
                state.userDisplayName = name
                return .none
                
            case .networking:
                return .none

            case .connection:
                return .none
            }
        }
    }
}
