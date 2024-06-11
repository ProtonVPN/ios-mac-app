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
        case startLoading
        case loadingViewOnAppear
        case finishedLoading(Result<Void, Error>)
    }

    static let tryAgainPeriod: Duration = .seconds(30)

    private enum CancelID { case timer }

    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loaded:
                return .none
            case .startLoading:
                state = .loading
                return .none
            case .finishedLoading(let result):
                switch result {
                case .success:
                    state = .loaded(.init())
                    break
                case .failure:
                    state = .loadingFailed
                    return .run { send in
                        try? await clock.sleep(for: Self.tryAgainPeriod)
                        await send(.startLoading)
                    }
                    .cancellable(id: CancelID.timer, cancelInFlight: true)
                }
                return .none
            case .loadingViewOnAppear:
                @Dependency(\.serverRepository) var repository
                @Dependency(\.logicalsRefresher) var refresher
                if refresher.shouldRefreshLogicals() || repository.isEmpty {
                    return .run { send in
                        await send(.finishedLoading(Result { try await refresher.refreshLogicals() }))
                    }
                } else {
                    return .run { send in
                        await send(.finishedLoading(.success(Void())))
                    }
                }
            }
        }
        .ifCaseLet(\.loaded, action: \.loaded) {
            HomeFeature()
        }
    }
}
