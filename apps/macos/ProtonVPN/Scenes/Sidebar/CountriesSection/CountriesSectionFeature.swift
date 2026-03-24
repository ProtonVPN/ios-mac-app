//
//  Created on 27.06.19.
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
import Countries
import Foundation

@Reducer
struct CountriesSectionFeature {
    @ObservableState
    struct State: Equatable {
        var countriesList = CountriesListFeature.State()
        var quickSettings = QuickSettingsFeature.State()
        var hasStartedQuickSettings = false
    }

    @CasePathable
    enum Action {
        case onAppear

        case countriesList(CountriesListFeature.Action)
        case quickSettings(QuickSettingsFeature.Action)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case openProfilesTab
        }
    }

    private let quickSettingsEnvironment: QuickSettingsFeature.Environment

    init(
        quickSettingsEnvironment: QuickSettingsFeature.Environment,
    ) {
        self.quickSettingsEnvironment = quickSettingsEnvironment
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.countriesList, action: \.countriesList) {
            CountriesListFeature()
        }
        Scope(state: \.quickSettings, action: \.quickSettings) {
            QuickSettingsFeature(environment: quickSettingsEnvironment)
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.hasStartedQuickSettings {
                    return .send(.quickSettings(.dismissDetails))
                }
                state.hasStartedQuickSettings = true
                return .merge(
                    .send(.quickSettings(.dismissDetails)),
                    .send(.quickSettings(.startObserving)),
                    .send(.countriesList(.listenForSecureCoreUpdates))
                )
            case .countriesList, .quickSettings, .delegate:
                return .none
            }
        }
    }
}
