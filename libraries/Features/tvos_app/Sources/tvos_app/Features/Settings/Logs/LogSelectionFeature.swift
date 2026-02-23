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
import PMLogger

@Reducer
struct LogSelectionFeature {
    @ObservableState
    struct State: Equatable {
        var logSources: [LogSource] = LogSource.visibleAppSources
    }

    enum Action {
        case logSelected(LogSource)
        case onExitCommand
    }

    @Dependency(\.dismiss) private var dismiss

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .logSelected:
                .none
            case .onExitCommand:
                .run { _ in await dismiss() }
            }
        }
    }
}
