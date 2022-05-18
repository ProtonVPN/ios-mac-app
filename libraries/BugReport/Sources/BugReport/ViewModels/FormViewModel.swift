//
//  Created on 2022-01-12.
//
//  Copyright (c) 2022 Proton AG
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

@available(iOS 14.0, *)
final class FormViewModel: ObservableObject {

    @Published var fields: [FormInputField]
    @Published var isSending: Bool = false
    @Published var sendResult: BugReportDelegate.SendReportResult? {
        didSet {
            sendResultChanged?()
        }
    }

    var showLogsInfo: Bool {
        return fields.last?.boolValue == false
    }

    // Lint is disbled here, because swiftui doesn't like get-only properties
    var shouldShowResultView: Bool { get { sendResult != nil } set {} } // swiftlint:disable:this unused_setter_value
    var sendResultError: Error? {
        if case .failure(let error) = sendResult {
            return error
        }
        return nil
    }

    var canBeSent: Bool {
        var result = true

        // Check if any of mandatory fields are not filled in
        for field in fields {
            // IsMandatory - optional boolean, if the field is absent, the input field is mandatory
            guard field.inputField.isMandatory ?? true else { continue }

            switch field.inputField.type {
            case .textSingleLine, .textMultiLine:
                if field.stringValue.isEmpty {
                    result = false
                }
            case .switch:
                if !field.boolValue {
                    result = false
                }
            }
        }

        return result
    }

    var sendResultChanged: (() -> Void)?

    // MARK: - User actions

    func sendTapped() {
        guard canBeSent && !isSending else { return }
        isSending = true
        self.sendResult = nil

        delegate?.send(form: makeResult(), result: { requestResult in
            self.isSending = false
            self.sendResult = requestResult
        })
    }

    func troubleshootingTapped() {
        delegate?.troubleshootingRequired()
    }

    func finished() {
        delegate?.finished()
    }

    // MARK: - Other

    private weak var delegate: BugReportDelegate? = CurrentEnv.bugReportDelegate
    private let emailFieldName = "_email"
    private let logsFieldName = "_logs"

    init(fields: [InputField], category: String?) {
        var formFields: [FormInputField] = []

        // Email field is always first
        formFields.append(FormInputField(
            inputField: InputField(
                label: LocalizedString.br3Email,
                submitLabel: emailFieldName,
                type: .textSingleLine,
                isMandatory: true,
                placeholder: nil
            ),
            stringValue: delegate?.prefilledEmail ?? ""
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

    private func makeResult() -> BugReportResult {
        let find = { (submitLabel: String) -> FormInputField? in
            return self.fields.first(where: { $0.inputField.submitLabel == submitLabel })
        }

        let email = find(emailFieldName)?.stringValue ?? ""
        let logs = find(logsFieldName)?.boolValue ?? false
        let text = fields.filter({ ![emailFieldName, logsFieldName, usernameFieldName].contains($0.inputField.submitLabel) }).reduce("") { prev, field in
            switch field.inputField.type {
            case .textSingleLine, .textMultiLine:
                return prev + "\(field.inputField.submitLabel)\n\(field.stringValue)\n---\n"
            case .switch:
                return prev + "\(field.inputField.submitLabel): \(field.boolValue ? "YES" : "NO")\n---\n"
            }
        }

        return BugReportResult(email: email, text: text, logs: logs)
    }
}
