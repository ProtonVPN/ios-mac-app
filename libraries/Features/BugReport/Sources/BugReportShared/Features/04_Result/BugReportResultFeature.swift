//
//  Created on 2023-05-03.
//
//  Copyright (c) 2023 Proton AG
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
import Dependencies
import Foundation

@Reducer
struct BugReportResultFeature {
    @ObservableState
    struct State: Equatable {
        var error: String?
        var troubleshoot: TroubleshootFeature.State?
        var isTroubleshootPresented = false
    }

    enum Action {
        case finish
        case setSheet(isPresented: Bool)
        case troubleshoot(TroubleshootFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .finish:
                return .run(priority: .userInitiated) { _ in
                    @Dependency(\.finishBugReport) var finish
                    finish()
                }

            case .setSheet(isPresented: true):
                state.isTroubleshootPresented = true
                state.troubleshoot = .init()
                return .none

            case .setSheet(isPresented: false):
                state.isTroubleshootPresented = false
                state.troubleshoot = nil
                return .none

            case .troubleshoot(.closeButtonTapped):
                return .send(.setSheet(isPresented: false))

            case .troubleshoot:
                return .none
            }
        }
        .ifLet(\.troubleshoot, action: \.troubleshoot) {
            TroubleshootFeature()
        }
    }
}
