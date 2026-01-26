//
//  DiscourageSecureCoreFeature.swift
//  Countries
//
//  Created on 22/01/2026.
//
//  Copyright (c) 2026 Proton AG
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
import Foundation
import LegacyCommon
import Strings

@Reducer
struct DiscourageSecureCoreFeature {
    @ObservableState
    struct State: Equatable {
        var dontShowAgain: Bool = false
    }

    enum Action: Equatable {
        case learnMoreTapped
        case activateTapped
        case toggleDontShowAgain
    }

    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.linkOpener) private var linkOpener

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleDontShowAgain:
                state.dontShowAgain.toggle()
                propertiesManager.discourageSecureCore = !state.dontShowAgain
                return .none

            case .learnMoreTapped:
                linkOpener.open(.learnMore)
                return .none

            case .activateTapped:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
