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

@Reducer
struct SignInFeature {
    @Reducer(state: .equatable)
    enum Destination {
        case settings(SettingsFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var signInCode: String?
        var loggedIn: Bool
        var pollAttempt: Int = 0
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case pollServer
        case fetchSignInCode
        case presentSignInCode(String)
        case signInSuccess(String)
    }

    @Dependency(NetworkClient.self) var networkClient
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .pollServer:
                if state.pollAttempt > 6 {
                    print("failed polling")
                    return .none
                }
                state.pollAttempt += 1
                return .run { send in
                    do {
                        let username = try await networkClient.forkSession()
                        await send(.signInSuccess(username))
                    } catch {
                        try await Task.sleep(for: .seconds(1)) // wait a second before trying again
                        await send(.pollServer)
                    }
                }
            case .signInSuccess(let userName):
                state.destination = .settings(.init(userName: userName))
                return .none
            case .destination(_):
                return .none
            case .fetchSignInCode:
                return .run { send in
                    let code = try await networkClient.fetchSignInCode()
                    await send(.presentSignInCode(code))
                }
            case .presentSignInCode(let code):
                state.signInCode = code
                return .run { send in
                    try await Task.sleep(for: .seconds(1)) // wait a second before polling starts
                    await send(.pollServer)
                }
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
