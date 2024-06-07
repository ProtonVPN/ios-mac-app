//
//  Created on 09/06/2024.
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
struct HomeLoadingFeature {

    @ObservableState
    enum State: Equatable {
        case loaded(HomeFeature.State)
        case loading
        case loadingFailed
    }

    enum Action {
        case loaded(HomeFeature.Action)
        case loading
        case loadingFailed
        case onAppear
        case finishedLoading
    }

    private enum CancelID { case timer }

    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loaded:
                return .none
            case .loading:
                return .none
            case .finishedLoading:
                return .none
            case .loadingFailed:
                state = .loadingFailed
                return .run { send in
                    try? await clock.sleep(for: .seconds(30))
                    await send(.onAppear)
                }
                .cancellable(id: CancelID.timer, cancelInFlight: true)
            case .onAppear:
                @Dependency(\.serverRepository) var repository
                @Dependency(\.logicalsRefresher) var refresher
                if repository.isEmpty || refresher.shouldRefreshLogicals() {
                    state = .loading
                    return .run { send in
                        try await refresher.refreshLogicalsIfNeeded()
                        await send(.finishedLoading)
                    } catch: { error, action in
                        await action(.loadingFailed)
                    }
                } else {
                    return .run { send in
                        await send(.finishedLoading)
                    }
                }
            }
        }
        .ifCaseLet(\.loaded, action: \.loaded) {
            HomeFeature()
        }
    }
}
