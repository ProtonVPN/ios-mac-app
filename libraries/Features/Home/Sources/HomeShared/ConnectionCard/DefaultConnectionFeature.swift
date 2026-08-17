//
//  Created on 22/11/2024.
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

import Collections
import ComposableArchitecture
import ConnectionInventory
import Domain
import VPNAppCore

@Reducer
public struct DefaultConnectionFeature {
    public typealias ActionSender = (Action) -> Void

    @Dependency(\.widgetReload) var widgetReload

    public init() {}

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.recentConnections) var recents
        @Shared(.storedDefaultConnectionPreference) public var defaultConnectionPreference: DefaultConnectionPreference?

        public var dynamicPreferenceModels: [ConnectionPreferenceModel] {
            @Dependency(\.defaultConnectionResolver) var resolver
            return resolver.preferenceModels(recents: recents ?? [])
        }

        public init() {}
    }

    public enum Action {
        case preferenceSelected(DefaultConnectionPreference)
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .preferenceSelected(preference):
                state.$defaultConnectionPreference.withLock { $0 = preference }
                widgetReload.reloadAllTimelines(.defaultConnectionChanged)
                return .none
            }
        }
    }
}
