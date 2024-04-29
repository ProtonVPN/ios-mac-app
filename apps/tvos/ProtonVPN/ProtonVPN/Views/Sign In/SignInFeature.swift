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
        var serverPoll: ServerPoll
        var selector: String?
        
        init(destination: Destination.State? = nil,
             signInCode: String? = nil,
             loggedIn: Bool,
             serverPoll: ServerPoll = .init(configuration: .default),
             selector: String? = nil) {
            self.destination = destination
            self.signInCode = signInCode
            self.loggedIn = loggedIn
            self.serverPoll = serverPoll
            self.selector = selector
        }
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case pollServer
        case fetchSignInCode
        case presentSignInCode(SignInCode)
        case signInSuccess(AuthCredentials)
    }

    @Dependency(NetworkClient.self) var networkClient
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .pollServer:
                guard let selector = state.selector, 
                        state.serverPoll.tick() else {
                    print("failed polling")
                    return .none
                }
                let delay = state.serverPoll.configuration.periodInSeconds
                return .run { send in
                    let credentials = try await networkClient.forkedSession(selector)
                    await send(.signInSuccess(credentials))
                } catch: { error, send in
                    try? await Task.sleep(for: .seconds(delay)) // wait before trying again
                    await send(.pollServer)
                }
            case .signInSuccess(let credentials):
                state.destination = .settings(.init(userName: credentials.userID))
                return .none
            case .fetchSignInCode:
                return .run { send in
                    let code = try await networkClient.fetchSignInCode()
                    await send(.presentSignInCode(code))
                } catch: { error, send in
                    // TODO: Failed obtaining user code and selector, present to the user to try again later?
                }
            case .presentSignInCode(let code):
                state.signInCode = code.userCode
                state.selector = code.selector
                let delay = state.serverPoll.configuration.delayBeforePollingStartsInSeconds
                return .run { [delay] send in
                    try? await Task.sleep(for: .seconds(delay))
                    await send(.pollServer)
                }
            case .destination(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

struct ServerPoll: Equatable {
    struct Configuration: Equatable {
        let delayBeforePollingStartsInSeconds: Int
        let periodInSeconds: Int
        let failAfterAttempts: Int
        static var `default` = Configuration(delayBeforePollingStartsInSeconds: 5,
                                             periodInSeconds: 1,
                                             failAfterAttempts: 5)
    }
    
    let configuration: Configuration

    lazy var remainingTicks: Int = configuration.failAfterAttempts

    mutating func tick() -> Bool {
        if remainingTicks < 1 {
            remainingTicks = configuration.failAfterAttempts
            return false
        }
        remainingTicks -= 1
        return true
    }
}
