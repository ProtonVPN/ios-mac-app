//
//  Created on 2023-04-17.
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

import CommonNetworking
import ComposableArchitecture
import Foundation

@Reducer
struct WhatsTheIssueFeature {
    @ObservableState
    struct State: Equatable {
        var categories: [CommonNetworking.Category]
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case categorySelected(CommonNetworking.Category)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { _, action in
            switch action {
            case .binding:
                .none

            case .categorySelected:
                .none
            }
        }
    }
}
