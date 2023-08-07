//
//  Created on 2023-05-10.
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

import XCTest
import ComposableArchitecture
@testable import BugReport

@MainActor
final class ContactFormTests: XCTestCase {

    private let delegate = MockBugReportDelegate(model: .mock)

    private var categoryWithoutQuickFixes: BugReport.Category {
        delegate.model.categories.last!
    }

    func testFormAcceptsDataFromUser() async throws {
        // Short String
        let shortStringField = InputField(label: "Short string field",
                                     submitLabel: "Don't care",
                                     type: .textSingleLine,
                                     isMandatory: true,
                                     placeholder: nil)
        let shortStringFormField = FormInputField(inputField: shortStringField)

        // Long String
        let longStringField = InputField(label: "Long string field",
                                         submitLabel: "Don't care here too",
                                         type: .textMultiLine,
                                         isMandatory: true,
                                         placeholder: nil)
        let longStringFormField = FormInputField(inputField: longStringField)

        // Boolean
        let boolField = InputField(label: "Boolean field",
                                         submitLabel: "Boolean value",
                                         type: .switch,
                                         isMandatory: true,
                                         placeholder: nil)
        let boolFormField = FormInputField(inputField: longStringField)

        let store = TestStore(
            initialState: ContactFormFeature.State(fields: [shortStringField, longStringField, boolField], category: "Category"),
            reducer: { ContactFormFeature() }
        )

        // Short String
        await store.send(.fieldStringValueChanged(shortStringFormField, "New value"), assert: { resultState in
            resultState.fields[id: shortStringFormField.id]?.stringValue = "New value"
        })

        // Long String
        await store.send(.fieldStringValueChanged(longStringFormField, "New  very long value"), assert: { resultState in
            resultState.fields[id: longStringFormField.id]?.stringValue = "New  very long value"
        })

        // Boolean
        await store.send(.fieldBoolValueChanged(boolFormField, true), assert: { resultState in
            resultState.fields[id: boolFormField.id]?.boolValue = true
        })
        await store.send(.fieldBoolValueChanged(boolFormField, false), assert: { resultState in
            resultState.fields[id: boolFormField.id]?.boolValue = false
        })

    }

    func testFormIsSent() async throws {
        let store = TestStore(
            // ContactFormFeature.State initialiser automatically adds few fields, like email, which is mandatory
            initialState: ContactFormFeature.State(fields: [], category: "Category"),
            reducer: { ContactFormFeature() },
            withDependencies: {
                $0.sendBugReport = { bugReportResult async throws in
                    XCTAssertEqual(bugReportResult.email, "email@hotmail.com")
                    try await Task.sleep(nanoseconds: UInt64(1)) // Let's make this truly async
                    return true
                }
            }
        )

        // Mandatory field is not filled
        XCTAssertFalse(store.state.canBeSent)

        let emailField = store.state.fields.first!
        await store.send(.fieldStringValueChanged(emailField, "email@hotmail.com"), assert: { resultState in
            resultState.fields[id: emailField.id]?.stringValue = "email@hotmail.com"
        })

        // Mandatory field is filled
        XCTAssertTrue(store.state.canBeSent)

        // Send bug report
        await store.send(.send, assert: { resultState in
            resultState.isSending = true // UI shows that somethings happening
        })
        await store.receive(.sendResponseReceived(TaskResult { true }), assert: { resultState in
            resultState.isSending = false
            resultState.resultState = BugReportResultFeature.State(error: nil)
        })
        await store.send(.resultViewClosed, assert: { resultState in
            resultState.resultState = nil
        })
    }

    func testErrorIsPresented() async throws {
        let errorThrown = BugReportEnvironmentError.delegateNotSet

        let store = TestStore(
            // ContactFormFeature.State initialiser automatically adds few fields, like email, which is mandatory
            initialState: ContactFormFeature.State(fields: [], category: "Category"),
            reducer: { ContactFormFeature() },
            withDependencies: {
                $0.sendBugReport = { bugReportResult async throws in
                    XCTAssertEqual(bugReportResult.email, "email@hotmail.com")
                    try await Task.sleep(nanoseconds: UInt64(1)) // Let's make this truly async
                    throw errorThrown
                }
                $0.finishBugReport = { }
            }
        )

        // Mandatory field is not filled
        XCTAssertFalse(store.state.canBeSent)

        let emailField = store.state.fields.first!
        await store.send(.fieldStringValueChanged(emailField, "email@hotmail.com"), assert: { resultState in
            resultState.fields[id: emailField.id]?.stringValue = "email@hotmail.com"
        })

        // Mandatory field is filled
        XCTAssertTrue(store.state.canBeSent)

        await store.send(.send, assert: { resultState in
            resultState.isSending = true // UI shows that somethings happening
        })
        await store.receive(.sendResponseReceived(TaskResult.failure(errorThrown)), assert: { resultState in
            resultState.isSending = false
            resultState.resultState = BugReportResultFeature.State(error: errorThrown.localizedDescription)
        })

        // Pressing Retry in result window moves user back to form
        await store.send(.resultViewAction(.retry), assert: { resultState in
            resultState.resultState = nil
        })
    }

}
