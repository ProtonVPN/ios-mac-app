//
//  Created on 2023-04-27.
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
import SwiftUI

@Reducer
struct QuickFixesFeature: Reducer {

    @ObservableState
    struct State: Equatable {
        var category: Category
        var contactFormState: ContactFormFeature.State?

        init(category: Category, contactFormState: ContactFormFeature.State? = nil) {
            self.category = category
            self.contactFormState = contactFormState
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case next
        case contactFormAction(ContactFormFeature.Action)
        case contactFormDeselected // Used only on mac
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .next:
                state.contactFormState = ContactFormFeature.State(fields: state.category.inputFields, category: state.category.label)
                return .none

            // 03. Contact form

            case .contactFormDeselected:
                state.contactFormState = nil
                return .none

            case .contactFormAction:
                return .none

            case .binding(_):
                // Everything's done in BindingReducer()
                return .none
            }
        }
        .ifLet(\.contactFormState, action: /Action.contactFormAction) {
            ContactFormFeature()
        }
    }

}
