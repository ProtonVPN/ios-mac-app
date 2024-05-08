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
    @ObservableState
    struct State: Equatable {
        var signInCode: String?
        var selector: String?
        var remainingAttempts: Int
        @Shared(.appStorage("username")) var userName: String?

        init(signInCode: String? = nil, selector: String? = nil) {
            self.signInCode = signInCode
            self.selector = selector
            @Dependency(ServerPollConfiguration.self) var serverPoll
            self.remainingAttempts = serverPoll.failAfterAttempts
        }
    }

    enum Action {
        case pollServer
        case fetchSignInCode
        case presentSignInCode(SignInCode)
        case signInSuccess(AuthCredentials)
    }

    @Dependency(NetworkClient.self) var networkClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case timer }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .pollServer:
                guard let selector = state.selector,
                      state.remainingAttempts > 0 else {
                    return .cancel(id: CancelID.timer)
                }
                state.remainingAttempts -= 1
                return .run { send in
                    let credentials = try await networkClient.forkedSession(selector)
                    await send(.signInSuccess(credentials))
                } catch: { error, send in
                    // failed to fork session
                }
            case .signInSuccess(let credentials):
                state.userName = credentials.userID // setting this causes the MainView to appear
                return .cancel(id: CancelID.timer)
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
                @Dependency(ServerPollConfiguration.self) var serverPollConfig
                state.remainingAttempts = serverPollConfig.failAfterAttempts
                return .run { [serverPollConfig] send in
                    try? await clock.sleep(for: serverPollConfig.delayBeforePollingStarts)
                    for await _ in clock.timer(interval: serverPollConfig.period) {
                        await send(.pollServer)
                    }
                }
                .cancellable(id: CancelID.timer, cancelInFlight: true)
            }
        }
    }
}
