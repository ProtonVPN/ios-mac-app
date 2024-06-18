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

    @ObservableState
    struct State: Equatable {
        var fields: IdentifiedArrayOf<FormInputField>
        var isSending: Bool = false
        var resultState: BugReportResultFeature.State?

        init(fields: IdentifiedArrayOf<FormInputField>, isSending: Bool, resultState: BugReportResultFeature.State? = nil) {
            self.fields = fields
            self.isSending = isSending
            self.resultState = resultState
        }

        // MARK: State helpers

        // This code was moved out of extension and into the struct here
        // because of the swift bug:
        // https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducers#Circular-reference-errors
        // https://github.com/apple/swift/issues/66450

        var showLogsInfo: Bool {
            return fields.last?.boolValue == false
        }

        var canBeSent: Bool {
            // Make sure that none of the mandatory fields contains empty value or unchecked switch
            // IsMandatory - optional boolean, if the field is absent, the input field is mandatory
            return !fields.filter({ $0.inputField.isMandatory ?? true }).contains(where: {
                switch $0.inputField.type {
                case .textSingleLine, .textMultiLine:
                    return $0.stringValue.isEmpty
                case .switch:
                    return !$0.boolValue
                }
            })
        }

        init(fields: [InputField], category: String?) {
            var formFields = IdentifiedArrayOf<FormInputField>()

            @Dependency(\.preFilledEmail) var preFilledEmail
            @Dependency(\.preFilledUsername) var preFilledUsername

            // Email field is always first
            formFields.append(FormInputField(
                inputField: InputField(
                    label: Localizable.br3Email,
                    submitLabel: emailFieldName,
                    type: .textSingleLine,
                    isMandatory: true,
                    placeholder: nil
                ),
                stringValue: preFilledEmail() ?? ""
            ))

            // Username field is always second
            formFields.append(FormInputField(
                inputField: InputField(
                    label: Localizable.br3Username,
                    submitLabel: usernameFieldName,
                    type: .textSingleLine,
                    isMandatory: false,
                    placeholder: nil
                ),
                stringValue: preFilledUsername() ?? ""
            ))

            if let categoryField = Self.categoryFormInputField(category) {
                formFields.append(categoryField)
            }

            formFields.append(contentsOf: fields.map { FormInputField(inputField: $0) })

            // Logs field is always last
            formFields.append(FormInputField(
                inputField: InputField(
                    label: Localizable.br3LogsField,
                    submitLabel: logsFieldName,
                    type: .switch,
                    isMandatory: false,
                    placeholder: Localizable.br3LogsDescription),
                boolValue: true)
            )

            self.fields = formFields
        }

        private static func categoryFormInputField(_ category: String?) -> FormInputField? {
            guard let category = category else {
                return nil
            }
            let inputField = InputField(
                label: "",
                submitLabel: "Category",
                type: .textSingleLine,
                isMandatory: false,
                placeholder: nil
            )
            return FormInputField(
                inputField: inputField,
                stringValue: category,
                boolValue: false,
                hidden: true
            )
        }

        func makeResult() -> BugReportResult {
            let find = { (submitLabel: String) -> FormInputField? in
                return self.fields.first(where: { $0.inputField.submitLabel == submitLabel })
            }

            let email = find(emailFieldName)?.stringValue ?? ""
            let username = find(usernameFieldName)?.stringValue ?? ""
            let logs = find(logsFieldName)?.boolValue ?? false
            let text = fields.filter({ ![emailFieldName, logsFieldName, usernameFieldName].contains($0.inputField.submitLabel) }).reduce("") { prev, field in
                let headerSeparator: String = prev.isEmpty ? " " : "\n"
                switch field.inputField.type {
                case .textSingleLine, .textMultiLine:
                    return prev + "\(field.inputField.submitLabel):\(headerSeparator)\(field.stringValue)\n---\n"
                case .switch:
                    return prev + "\(field.inputField.submitLabel): \(field.boolValue ? "YES" : "NO")\n---\n"
                }
            }

            return BugReportResult(email: email, username: username, text: text, logs: logs)
        }

    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
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

            case .binding(_):
                // Everything's done in BindingReducer()
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

private let emailFieldName = "_email"
private let usernameFieldName = "_username"
private let logsFieldName = "_logs"
