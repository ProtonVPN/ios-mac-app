//
//  Created on 09/02/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Foundation
import PMLogger

@Reducer
struct LogsFeature {
    @ObservableState
    struct State: Equatable {
        let logSource: LogSource
        var logs: String = ""
        var isLoading = false

        var title: String {
            logSource.title
        }
    }

    enum Action {
        case onAppear
        case onExitCommand
        case logsLoaded(String)
    }

    @Dependency(\.logContentProvider) private var logContentProvider
    @Dependency(\.dismiss) private var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.logs.isEmpty else { return .none }
                state.isLoading = true
                let source = state.logSource
                return .run { send in
                    let content = logContentProvider.getLogData(for: source)
                    let logs = await content.loadContent()
                    await send(.logsLoaded(logs))
                }
            case let .logsLoaded(logs):
                state.isLoading = false
                state.logs = logs
                return .none
            case .onExitCommand:
                return .run { _ in await dismiss() }
            }
        }
    }
}
