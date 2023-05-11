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

import Foundation
import ComposableArchitecture

struct WhatsTheIssueFeature: Reducer {

    struct State: Equatable {
        var categories: [Category]

        var quickFixesState: QuickFixesFeature.State?
        var contactFormState: ContactFormFeature.State?
    }

    enum Action: Equatable {
        case categorySelected(Category)

        case quickFixesAction(QuickFixesFeature.Action)
        case quickFixesDeselected

        case contactFormAction(ContactFormFeature.Action)
        case contactFormDeselected
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .categorySelected(let category):
                if let suggestions = category.suggestions, !suggestions.isEmpty {
                    state.quickFixesState = QuickFixesFeature.State(category: category)
                } else {
                    state.contactFormState = ContactFormFeature.State(fields: category.inputFields, category: category.label)
                }

                return .none

            // 02. Quick fixes

            case .quickFixesDeselected:
                state.quickFixesState = nil
                return .none

            case .quickFixesAction:
                return .none

            // 03. Contact form

            case .contactFormAction:
                return .none

            case .contactFormDeselected:
                state.contactFormState = nil
                return .none

            }
        }
        .ifLet(\.quickFixesState, action: /Action.quickFixesAction) {
            QuickFixesFeature()
        }
        .ifLet(\.contactFormState, action: /Action.contactFormAction) {
            ContactFormFeature()
        }
    }

}
