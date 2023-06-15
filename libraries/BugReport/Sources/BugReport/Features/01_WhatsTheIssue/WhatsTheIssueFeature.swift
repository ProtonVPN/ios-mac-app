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
        var route: Route.State?
    }

    enum Action: Equatable {
        case categorySelected(Category)
        case route(Route.Action)

        case quickFixesAction(QuickFixesFeature.Action)
        case quickFixesDeselected

        case contactFormAction(ContactFormFeature.Action)
        case contactFormDeselected
    }

    struct Route: Equatable {

        enum State: Equatable {
            case quickFixes(QuickFixesFeature.State)
            case contactForm(ContactFormFeature.State)
        }

        enum Action: Equatable {
            case quickFixes(QuickFixesFeature.Action)
            case contactForm(ContactFormFeature.Action)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .categorySelected(let category):
                if let suggestions = category.suggestions, !suggestions.isEmpty {
                    state.route = .quickFixes(QuickFixesFeature.State(category: category))
                } else {
                    state.route = .contactForm(ContactFormFeature.State(fields: category.inputFields, category: category.label))
                }
                return .none

            case .route:
                return .none

            // 02. Quick fixes

            case .quickFixesDeselected:
                state.route = nil
                return .none

            case .quickFixesAction:
                return .none

            // 03. Contact form

            case .contactFormAction:
                return .none

            case .contactFormDeselected:
                state.route = nil
                return .none

            }
        }
        .ifLet(\.route, action: /Action.route, then: {
            Scope(state: /Route.State.quickFixes, action: /Route.Action.quickFixes, child: {
                QuickFixesFeature()
            })
            Scope(state: /Route.State.contactForm, action: /Route.Action.contactForm, child: {
                ContactFormFeature()
            })
        })
    }

}
