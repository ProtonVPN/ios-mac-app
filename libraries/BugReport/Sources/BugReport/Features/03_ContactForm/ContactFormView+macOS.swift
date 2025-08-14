//
//  Created on 2023-05-11.
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

#if os(macOS)
    import ComposableArchitecture
    import Foundation
    import Strings
    import SwiftUI

    public struct ContactFormView: View {
        @Perception.Bindable var store: StoreOf<ContactFormFeature>

        @Environment(\.colors) var colors: Colors
        @Environment(\.dismiss) private var dismiss

        public var body: some View {
            WithPerceptionTracking {
                ZStack {
                    colors.background.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(store.fields) { field in
                                if !field.hidden {
                                    switch field.inputField.type {
                                    case .textSingleLine:
                                        SingleLineTextInputView(
                                            field: field.inputField,
                                            value: Binding(
                                                get: { field.stringValue },
                                                set: {
                                                    guard $0 != field.stringValue else { return }
                                                    store.send(.fieldStringValueChanged(field, $0))
                                                }
                                            )
                                        )
                                    case .textMultiLine:
                                        MultiLineTextInputView(
                                            field: field.inputField,
                                            value: Binding(
                                                get: { field.stringValue },
                                                set: {
                                                    guard $0 != field.stringValue else { return }
                                                    store.send(.fieldStringValueChanged(field, $0))
                                                }
                                            )
                                        )
                                        .frame(height: 155, alignment: .top)
                                    case .switch:
                                        SwitchInputView(
                                            field: field.inputField,
                                            value: Binding(
                                                get: { field.boolValue },
                                                set: { store.send(.fieldBoolValueChanged(field, $0)) }
                                            )
                                        )
                                    }
                                }
                            }

                            if store.showLogsInfo {
                                HStack(alignment: .top, spacing: 0) {
                                    Image(Asset.icInfoCircle.name, bundle: Bundle.module)
                                        .padding(0)

                                    Text(Localizable.br3LogsDisabled)
                                        .font(.footnote)
                                        .foregroundColor(colors.textSecondary)
                                        .padding(.leading, 8)
                                }
                                .padding(.horizontal)
                            }

                            Button(action: {
                                store.send(.send, animation: .default)
                            }, label: {
                                Text(store.isSending ? Localizable.br3ButtonSending : Localizable.br3ButtonSend)
                            })
                            .disabled(!store.isSending && !store.canBeSent)
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
                .foregroundColor(colors.textPrimary)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: {
                            dismiss()
                        }, label: {
                            Image(systemName: "chevron.left").foregroundColor(colors.textPrimary)
                        })
                    }
                }
                .environment(\.isLoading, store.isSending)
            }
        }
    }

    // MARK: - Preview

    #Preview("Empty form") {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let formFields = IdentifiedArrayOf(uniqueElements: [FormInputField(inputField: bugReport.model.categories[0].inputFields[0], stringValue: "Entered value")])

        return ContactFormView(store: Store(
            initialState: ContactFormFeature.State(fields: bugReport.model.categories[0].inputFields, category: "aa"),
            reducer: { ContactFormFeature() }
        ))
        .frame(width: 400)
    }

    #Preview("Short form") {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let formFields = IdentifiedArrayOf(uniqueElements: [FormInputField(inputField: bugReport.model.categories[0].inputFields[0], stringValue: "Entered value")])

        return ContactFormView(store: Store(
            initialState: ContactFormFeature.State(fields: formFields, isSending: false),
            reducer: { ContactFormFeature() }
        ))
        .frame(width: 400)
    }

    #Preview("Loading") {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let formFields = IdentifiedArrayOf(uniqueElements: [FormInputField(inputField: bugReport.model.categories[0].inputFields[0], stringValue: "Entered value")])

        return ContactFormView(store: Store(
            initialState: ContactFormFeature.State(fields: formFields, isSending: true),
            reducer: { ContactFormFeature() }
        ))
        .frame(width: 400)
    }
#endif
