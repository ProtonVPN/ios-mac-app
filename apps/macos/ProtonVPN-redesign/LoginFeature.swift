//
//  Created on 13/07/2023.
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

public struct LoginFeature: ReducerProtocol {
    public struct State: Equatable {
        var initialError: String?
    }

    public enum Action: Equatable {
        case showError(initialError: String?)
        case loginButtonPressed(username: String, password: String)
    }

    public var body: some ReducerProtocolOf<LoginFeature> {
        Reduce { state, action in
            switch action {
            case .loginButtonPressed:
                return .none
            case .showError(let initialError):
                state.initialError = initialError
                return .none
            }
        }
    }
}
