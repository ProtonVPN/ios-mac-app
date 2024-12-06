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

import Foundation
import Collections

import ComposableArchitecture
import SharedViews

import struct Domain.ConnectionSpec
import struct Domain.RecentConnection

@Reducer
public struct DefaultConnectionFeature {
    public typealias ActionSender = (Action) -> Void

    public init() { }

    @ObservableState
    public struct State: Equatable {
        @Shared(.recents) public var recents: OrderedSet<RecentConnection>

        // Normally we should define these in the view layer, but we need the `ConnectionInfoBuilder` dependency
        public let staticPreferenceModels: [ConnectionPreferenceModel]
        public var dynamicPreferenceModels: [ConnectionPreferenceModel] {
            recents.map { DefaultConnectionFeature.model(for: $0) }
        }
        public var selection: DefaultConnectionPreference

        public init(selection: DefaultConnectionPreference) {
            self.selection = selection
            self.staticPreferenceModels = DefaultConnectionPreference.staticPreferences
                .map { DefaultConnectionFeature.model(for: $0) }
        }
    }

    @CasePathable
    public enum Action {
        case preferenceSelected(DefaultConnectionPreference)
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .preferenceSelected(let preference):
                state.selection = preference
                return .none
            }
        }
    }

    public static func model(for recentConnection: RecentConnection) -> ConnectionPreferenceModel {
        return model(for: .recent(recentConnection.connection))
    }

    public static func model(for preference: DefaultConnectionPreference) -> ConnectionPreferenceModel {
        switch preference {
        case .fastest:
            return ConnectionPreferenceModel(
                preference: .fastest,
                locationFeatureModel: LocationFeatureModel(
                    flag: .fastest,
                    header: .init(title: "Fastest", showConnectedPin: false),
                    subheader: .textual(.withoutFeatures(location: "The best server based on your location"))
                )
            )

        case .mostRecent:
            return ConnectionPreferenceModel(
                preference: .mostRecent,
                locationFeatureModel: .init(
                    flag: .mostRecent,
                    header: .init(title: "Most Recent", showConnectedPin: false),
                    subheader: .textual(.withoutFeatures(location: "Your most recently used connection"))
                )
            )

        case .recent(let spec):
            let infoBuilder = ConnectionInfoBuilder(intent: spec, vpnConnectionActual: nil, withServerNumber: true)
            return ConnectionPreferenceModel(
                preference: .recent(spec),
                locationFeatureModel: .init(
                    flag: spec.location.flagComposition,
                    header: .init(title: infoBuilder.textHeader, showConnectedPin: false),
                    subheader: infoBuilder.subheader
                )
            )
        }
    }
}

public enum DefaultConnectionPreference: Equatable, Hashable {
    case fastest
    case mostRecent
    case recent(ConnectionSpec)

    public static let staticPreferences: [Self] = [.fastest, .mostRecent]
}

public struct ConnectionPreferenceModel: Equatable, Hashable {
    package let preference: DefaultConnectionPreference
    package let locationFeatureModel: LocationFeatureModel

    public func hash(into hasher: inout Hasher) {
        hasher.combine(preference.hashValue)
    }
}
