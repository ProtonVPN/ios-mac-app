//
//  Created on 05/03/2026 by Max Kupetskyi.
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
public struct PaymentsWebCheckoutFeature {
    @ObservableState
    public struct State: Equatable {
        public let url: URL

        public init(url: URL) {
            self.url = url
        }
    }

    public enum Action {
        case completedFromWeb
        case closeTapped
        case delegate(Delegate)

        public enum Delegate {
            case completed
            case cancelled
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .completedFromWeb:
                .send(.delegate(.completed))
            case .closeTapped:
                .send(.delegate(.cancelled))
            case .delegate:
                .none
            }
        }
    }
}
