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
import Domain
import ConnectionPresenter

@Reducer
public struct DefaultConnectionFeature {
    public typealias ActionSender = (Action) -> Void

    public init() { }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.recents) var recents: OrderedSet<RecentConnection>
        @Shared(.defaultConnectionPreference) public var defaultConnectionPreference: DefaultConnectionPreference

        public var dynamicPreferenceModels: [ConnectionPreferenceModel] {
            @Dependency(\.defaultConnectionResolver) var resolver
            return resolver.preferenceModels(recents: recents)
        }

        public init() { }
    }

    @CasePathable
    public enum Action {
        case preferenceSelected(DefaultConnectionPreference)
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .preferenceSelected(let preference):
                state.$defaultConnectionPreference.withLock { $0 = preference }
                return .run { _ in
                    @Dependency(\.defaultConnectionStorage) var storage
                    try storage.set(preference: preference)
                } catch: { error, _ in
                    log.error("Error saving default connection preference", metadata: ["error": "\(error)"])
                }
            }
        }
    }
}
