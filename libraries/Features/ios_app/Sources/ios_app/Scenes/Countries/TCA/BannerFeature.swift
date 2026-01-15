//
//  Created on 08/01/2026 by Max Kupetskyi.
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

@Reducer
struct BannerFeature {
    enum BannerType: String, Equatable {
        case upsell
    }

    @ObservableState
    struct State: Equatable, Identifiable {
        let bannerType: BannerType

        var id: String { bannerType.rawValue }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case tapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .tapped:
                print("Banner tapped: \(state.bannerType)")
                return .none

            case .binding:
                return .none
            }
        }
    }
}
