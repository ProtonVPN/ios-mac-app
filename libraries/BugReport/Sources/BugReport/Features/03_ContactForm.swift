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
import SwiftUINavigation

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
        case cancel
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
                return .task(operation: {
                    await Action.sendResponseReceived(TaskResult {
                        @Dependency(\.sendBugReport) var sendBugReport
                        return try await sendBugReport(form)
                    })
                })

            case .sendResponseReceived(let response):
                state.isSending = false
                state.resultState = BugReportResultFeature.State(error: response.errorOrNil?.localizedDescription ?? nil )
                return .none

            case .resultViewClosed:
                state.resultState = nil
                return .none

            case .cancel:
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

private let emailFieldName = "_email"
private let usernameFieldName = "_username"
private let logsFieldName = "_logs"

extension ContactFormFeature.State {
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
                label: LocalizedString.br3Email,
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
                label: LocalizedString.br3Username,
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
                label: LocalizedString.br3LogsField,
                submitLabel: logsFieldName,
                type: .switch,
                isMandatory: false,
                placeholder: LocalizedString.br3LogsDescription),
            boolValue: true)
        )

        self.fields = formFields
    }

    private static func categoryFormInputField(_ category: String?) -> FormInputField? {
        guard let category = category else {
            return nil
        }
        let inputField = InputField(label: "",
                                    submitLabel: "Category",
                                    type: .textSingleLine,
                                    isMandatory: false,
                                    placeholder: nil)
        return FormInputField(inputField: inputField,
                              stringValue: category,
                              boolValue: false,
                              hidden: true)
    }
}

extension ContactFormFeature.State {
    func makeResult() -> BugReportResult {
        let find = { (submitLabel: String) -> FormInputField? in
            return self.fields.first(where: { $0.inputField.submitLabel == submitLabel })
        }

        let email = find(emailFieldName)?.stringValue ?? ""
        let username = find(usernameFieldName)?.stringValue ?? ""
        let logs = find(logsFieldName)?.boolValue ?? false
        let text = fields.filter({ ![emailFieldName, logsFieldName, usernameFieldName].contains($0.inputField.submitLabel) }).reduce("") { prev, field in
            switch field.inputField.type {
            case .textSingleLine, .textMultiLine:
                return prev + "\(field.inputField.submitLabel)\n\(field.stringValue)\n---\n"
            case .switch:
                return prev + "\(field.inputField.submitLabel): \(field.boolValue ? "YES" : "NO")\n---\n"
            }
        }

        return BugReportResult(email: email, username: username, text: text, logs: logs)
    }
}

#if os(iOS)
public struct ContactFormView: View {

    let store: StoreOf<ContactFormFeature>

    @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel

    @Environment(\.colors) var colors: Colors
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 0) {

                    StepProgress(step: 3, steps: 3, colorMain: colors.interactive, colorText: colors.textAccent, colorSecondary: colors.interactiveActive)
                        .padding(.bottom)

                    UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)

                    ScrollView {
                        VStack(spacing: 20) {

                            ForEach(viewStore.fields) { field in
                                if !field.hidden {

                                    switch field.inputField.type {
                                    case .textSingleLine:
                                        SingleLineTextInputView(field: field.inputField,
                                                                value: Binding(get: { field.stringValue },
                                                                               set: { viewStore.send(.fieldStringValueChanged(field, $0)) }))
                                    case .textMultiLine:
                                        MultiLineTextInputView(field: field.inputField,
                                                               value: Binding(get: { field.stringValue },
                                                                              set: { viewStore.send(.fieldStringValueChanged(field, $0)) }))
                                            .frame(height: 155, alignment: .top)
                                    case .switch:
                                        SwitchInputView(field: field.inputField,
                                                        value: Binding(get: { field.boolValue },
                                                                       set: { viewStore.send(.fieldBoolValueChanged(field, $0)) }))
                                    }
                                }
                            }

                            if viewStore.showLogsInfo {
                                HStack(alignment: .top, spacing: 0) {
                                    Image(Asset.icInfoCircle.name, bundle: Bundle.module)
                                        .padding(0)

                                    Text(LocalizedString.br3LogsDisabled)
                                        .font(.footnote)
                                        .foregroundColor(colors.textSecondary)
                                        .padding(.leading, 8)

                                }
                                .padding(.horizontal)
                            }

                            Button(action: {
                                viewStore.send(.send)
                            }, label: { Text(viewStore.isSending ? LocalizedString.br3ButtonSending : LocalizedString.br3ButtonSend) })
                                .disabled(!viewStore.isSending && !viewStore.canBeSent)
                                .buttonStyle(PrimaryButtonStyle())
                                .padding(.horizontal)
                        }
                    }

                    NavigationLink(unwrapping: viewStore.binding(get: \.resultState,
                                                                 send: ContactFormFeature.Action.resultViewClosed),
                                   onNavigate: { _ in },
                                   destination: { _ in
                                        IfLetStore(self.store.scope(state: \.resultState,
                                                    action: { .resultViewAction($0) }),
                                                   then: { store in BugReportResultView(store: store) })
                                    },
                                   label: { EmptyView() })

                }
                .foregroundColor(colors.textPrimary)

                // Custom Back button
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading: Button(action: {
                    self.dismiss()
                }, label: {
                    Image(systemName: "chevron.left").foregroundColor(colors.textPrimary)
                }))

                .environment(\.isLoading, viewStore.isSending)
            }
        })
    }

}

#elseif os(macOS)

public struct ContactFormView: View {

    let store: StoreOf<ContactFormFeature>

    @Environment(\.colors) var colors: Colors

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in
            VStack {
                VStack(spacing: 20) {
                    ForEach(viewStore.fields) { field in
                        if !field.hidden {
                            switch field.inputField.type {
                            case .textSingleLine:
                                SingleLineTextInputView(field: field.inputField,
                                                        value: Binding(get: { field.stringValue },
                                                                       set: { viewStore.send(.fieldStringValueChanged(field, $0)) }))
                            case .textMultiLine:
                                MultiLineTextInputView(field: field.inputField,
                                                       value: Binding(get: { field.stringValue },
                                                                      set: { viewStore.send(.fieldStringValueChanged(field, $0)) }))
                                .frame(height: 155, alignment: .top)
                            case .switch:
                                SwitchInputView(field: field.inputField,
                                                value: Binding(get: { field.boolValue },
                                                               set: { viewStore.send(.fieldBoolValueChanged(field, $0)) }))
                            }
                        }
                    }

                    if viewStore.showLogsInfo {
                        HStack(alignment: .top, spacing: 0) {
                            Image(Asset.icInfoCircle.name, bundle: Bundle.module)
                                .padding(0)

                            Text(LocalizedString.br3LogsDisabled)
                                .font(.footnote)
                                .foregroundColor(colors.textSecondary)
                                .padding(.leading, 8)

                        }
                        .padding(.horizontal)
                    }

                    Button(action: {
                        viewStore.send(.send, animation: .default)

                    }, label: { Text(viewStore.isSending ? LocalizedString.br3ButtonSending : LocalizedString.br3ButtonSend) })
                    .disabled(!viewStore.isSending && !viewStore.canBeSent)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                }
            }
            .environment(\.isLoading, viewStore.isSending)
            .background(colors.background)
        })
    }

}

#endif

fileprivate extension TaskResult<Bool> {
    var errorOrNil: Error? {
        if case TaskResult.failure(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Preview

struct ContactFormView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let formFields = IdentifiedArrayOf(uniqueElements: [FormInputField(inputField: bugReport.model.categories[0].inputFields[0], stringValue: "Entered value")])

        return Group {
            ContactFormView(store: Store(initialState: ContactFormFeature.State(fields: bugReport.model.categories[0].inputFields, category: "aa"),
                                         reducer: ContactFormFeature()))
            .previewDisplayName("Empty form")

            ContactFormView(store: Store(initialState: ContactFormFeature.State(fields: formFields, isSending: false),
                                         reducer: ContactFormFeature()))
            .previewDisplayName("Short form")
            
            ContactFormView(store: Store(initialState: ContactFormFeature.State(fields: formFields, isSending: true),
                                         reducer: ContactFormFeature()))
            .previewDisplayName("Loading")

        }
    }
}
