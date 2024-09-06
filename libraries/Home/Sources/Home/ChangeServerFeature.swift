//
//  Created on 02/09/2024.
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
import VPNAppCore
import Foundation

@Reducer
public struct ChangeServerFeature {

    @ObservableState
    public struct State: Equatable {
        public var dateFinished: Date
        public var totalDuration: TimeInterval

        public init(serverChangeAvailability: ServerChangeAuthorizer.ServerChangeAvailability) {
            switch serverChangeAvailability {
            case .available:
                self.dateFinished = .distantPast
                self.totalDuration = 0
            case let .unavailable(until, duration, _):
                self.dateFinished = until
                self.totalDuration = duration
            }
        }
    }

    @CasePathable
    public enum Action {
        case buttonTapped
    }

    public init() { }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .buttonTapped:
                return .none
            }
        }
    }
}
