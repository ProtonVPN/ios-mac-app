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

import Foundation
import ComposableArchitecture
import Dependencies

@Reducer
struct BugReportResultFeature: Reducer {

    @ObservableState
    struct State: Equatable {
        var error: String?
    }

    enum Action: Equatable {
        case finish
        case retry
        case troubleshoot
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .finish:
                return .run(priority: .userInitiated) { _ in
                    @Dependency(\.finishBugReport) var finish
                    finish()
                }
                
            case .retry:
                // Retry is done on the parent view
                return .none

            case .troubleshoot:
                return .run(priority: .userInitiated) { _ in
                    @Dependency(\.troubleshoot) var troubleshoot
                    troubleshoot()
                }
            }
        }
    }

}
