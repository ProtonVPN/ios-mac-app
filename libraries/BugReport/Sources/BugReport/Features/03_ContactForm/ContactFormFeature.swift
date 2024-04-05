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
import Strings

@Reducer
struct ContactFormFeature: Reducer {

    struct State: Equatable {
        var fields: IdentifiedArrayOf<FormInputField>
        var isSending: Bool = false
        var resultState: BugReportResultFeature.State?
    }

    enum Action: Equatable {
        case fieldStringValueChanged(FormInputField, String)
        case fieldBoolValueChanged(FormInputField, Bool)
        case send
        case sendResponseReceived(TaskResult<Bool>)
        case resultViewClosed
        case resultViewAction(BugReportResultFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fieldStringValueChanged(let field, let newValue):
                state.fields[id: field.id]?.stringValue = newValue
                return .none

            case .fieldBoolValueChanged(let field, let newValue):
                state.fields[id: field.id]?.boolValue = newValue
                return .none

            case .send:
                state.isSending = true
                let form = state.makeResult()
                return .run { send in
                    await send(.sendResponseReceived(TaskResult {
                        @Dependency(\.sendBugReport) var sendBugReport
                        return try await sendBugReport(form)
                    }))
                }

            case .sendResponseReceived(let response):
                state.isSending = false
                state.resultState = BugReportResultFeature.State(error: response.errorOrNil?.localizedDescription ?? nil )
                return .none

            case .resultViewClosed:
                state.resultState = nil
                return .none

            // 04. Results

            case .resultViewAction(.retry):
                state.resultState = nil
                return .none

            case .resultViewAction:
                return .none
            }
        }

        .ifLet(\.resultState, action: /Action.resultViewAction, then: { BugReportResultFeature() })

    }

}

fileprivate extension TaskResult<Bool> {
    var errorOrNil: Error? {
        if case TaskResult.failure(let error) = self {
            return error
        }
        return nil
    }
}
