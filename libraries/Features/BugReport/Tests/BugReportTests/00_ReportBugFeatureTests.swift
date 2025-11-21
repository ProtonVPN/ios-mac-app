//
//  Created on 14/08/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

@testable import BugReportShared
import CommonNetworking
import ComposableArchitecture
import Foundation
import Testing

@MainActor
struct ReportBugFeatureTests {
    private let delegate = MockBugReportDelegate(model: .mock)

    private var categoryWithQuickFixes: CommonNetworking.Category {
        delegate.model.categories.first!
    }

    private var categoryWithoutQuickFixes: CommonNetworking.Category {
        delegate.model.categories.last!
    }

    // MARK: - Tests

    @Test("Navigate to quick fixes")
    func choosingCategoryWithQuickFixesShouldNavigateToQuickFixes() async {
        let store = TestStore(
            initialState: ReportBugFeature.State(
                path: StackState(),
                whatsTheIssueState: .init(categories: delegate.model.categories)
            ),
            reducer: { ReportBugFeature() }
        )

        // Send categorySelected action for a category with quick fixes
        await store.send(.whatsTheIssueAction(.categorySelected(categoryWithQuickFixes))) {
            // Verify that the path now contains a quickFixes state
            $0.path.append(.quickFixes(QuickFixesFeature.State(category: categoryWithQuickFixes)))
        }

        // Verify the path contains the expected quick fixes state
        #expect(store.state.path.count == 1)
        if case let .quickFixes(quickFixesState) = store.state.path.first {
            #expect(quickFixesState.category.id == categoryWithQuickFixes.id)
            #expect(quickFixesState.category.label == categoryWithQuickFixes.label)
        } else {
            #expect(Bool(false), "Expected quickFixes path element")
        }
    }

    @Test("Navigate to contact form")
    func choosingCategoryWithQuickFixesShouldNavigateToContactForm() async {
        let store = TestStore(
            initialState: ReportBugFeature.State(
                path: StackState(),
                whatsTheIssueState: .init(categories: delegate.model.categories)
            ),
            reducer: { ReportBugFeature() }
        )

        // Send categorySelected action for a category without quick fixes
        await store.send(.whatsTheIssueAction(.categorySelected(categoryWithoutQuickFixes)))

        await store.receive(\.attemptContactUs) {
            // Verify that the path now contains a contactUs state
            $0.path[id: 0] = .contactUs(ContactFormFeature.State(fields: categoryWithoutQuickFixes.inputFields, category: categoryWithoutQuickFixes.label))
        }

        // Verify the path contains the expected contact form state
        #expect(store.state.path.count == 1)
        if case let .contactUs(contactFormState) = store.state.path.first {
            #expect(contactFormState.fields.count == 4) // default 4 fields
        } else {
            #expect(Bool(false), "Expected contactUs path element")
        }
    }

    @Test("Navigate to contact form when credentialless")
    func choosingCategoryWithQuickFixesWhenCredentiallessShouldShowAlert() async {
        let store = TestStore(
            initialState: ReportBugFeature.State(
                path: StackState(),
                whatsTheIssueState: .init(categories: delegate.model.categories)
            ),
            reducer: { ReportBugFeature() },
            withDependencies: {
                $0.isUserCredentialless = { true }
            }
        )

        // Send categorySelected action for a category without quick fixes
        await store.send(.whatsTheIssueAction(.categorySelected(categoryWithoutQuickFixes)))

        await store.receive(\.attemptContactUs) {
            $0.alert = ReportBugFeature().signInAlert
        }

        // nothing pushed onto stack
        #expect(store.state.path.isEmpty)
    }

    @Test("Navigate to quick fixes, then to contact form")
    func choosingCategoryWithQuickFixesThenNavigateToContactForm() async {
        let store = TestStore(
            initialState: ReportBugFeature.State(
                path: StackState(),
                whatsTheIssueState: .init(categories: delegate.model.categories)
            ),
            reducer: { ReportBugFeature() }
        )

        // First, navigate to quick fixes
        await store.send(.whatsTheIssueAction(.categorySelected(categoryWithQuickFixes))) {
            $0.path.append(.quickFixes(QuickFixesFeature.State(category: categoryWithQuickFixes)))
        }

        // Verify quick fixes navigation
        #expect(store.state.path.count == 1)
        if case let .quickFixes(quickFixesState) = store.state.path.first {
            #expect(quickFixesState.category.id == categoryWithQuickFixes.id)
        } else {
            #expect(Bool(false), "Expected quickFixes path element")
        }

        // Now test that we can navigate to contact form from quick fixes
        // This simulates the user completing quick fixes and needing to submit a form
        let contactFormState = ContactFormFeature.State(fields: categoryWithQuickFixes.inputFields, category: categoryWithQuickFixes.label)

        // Add contact form to the path
        await store.send(.path(.push(id: 1, state: .contactUs(contactFormState)))) {
            $0.path.append(.contactUs(contactFormState))
        }

        // Verify we now have both quick fixes and contact form
        #expect(store.state.path.count == 2)

        // Verify the path structure
        if case let .quickFixes(quickFixesState) = store.state.path.first {
            #expect(quickFixesState.category.id == categoryWithQuickFixes.id)
        } else {
            #expect(Bool(false), "Expected first path element to be quickFixes")
        }

        if case let .contactUs(contactFormState) = store.state.path.last {
            #expect(contactFormState.fields.count == categoryWithQuickFixes.inputFields.count + 4)
        } else {
            #expect(Bool(false), "Expected second path element to be contactUs")
        }
    }

    @Test("Navigate to quick fixes in credentialless, then attempt navigate to contact form")
    func choosingCategoryWithQuickFixesWhenCredentiallessThenTryToContactForm() async {
        let store = TestStore(
            initialState: ReportBugFeature.State(
                path: StackState(),
                whatsTheIssueState: .init(categories: delegate.model.categories)
            ),
            reducer: { ReportBugFeature() },
            withDependencies: {
                $0.isUserCredentialless = { true }
            }
        )

        // First, navigate to quick fixes
        await store.send(.whatsTheIssueAction(.categorySelected(categoryWithQuickFixes))) {
            $0.path.append(.quickFixes(QuickFixesFeature.State(category: categoryWithQuickFixes)))
        }

        // Verify quick fixes navigation
        #expect(store.state.path.count == 1)
        if case let .quickFixes(quickFixesState) = store.state.path.first {
            #expect(quickFixesState.category.id == categoryWithQuickFixes.id)
        } else {
            #expect(Bool(false), "Expected quickFixes path element")
        }

        // Now test that we can't navigate to contact form from quick fixes

        await store.send(.path(.element(id: 0, action: .quickFixes(.contactUs))))
        await store.receive(\.attemptContactUs) {
            $0.alert = ReportBugFeature().signInAlert
        }
    }

    @Test("Navigate to result from contact form")
    func fromContactFormNavigateToSuccessResult() async {
        var contactFormState = ContactFormFeature.State(fields: [], category: "Category")
        contactFormState.fields[id: "Email"]?.stringValue = "email@hotmail.com"

        let store = TestStore(
            initialState: ReportBugFeature.State(
                path: StackState(
                    [
                        .quickFixes(QuickFixesFeature.State(category: categoryWithQuickFixes)),
                        .contactUs(contactFormState),
                    ]
                ),
                whatsTheIssueState: .init(categories: delegate.model.categories)
            ),
            reducer: { ReportBugFeature() }
        )

        // send bug report
        await store.send(.path(.element(id: 1, action: .contactUs(.send)))) {
            $0.path[id: 1, case: \.contactUs]?.isSending = true
        }
        await store.receive(\.path[id: 1].contactUs.sendResponseReceived) {
            $0.path[id: 1, case: \.contactUs]?.isSending = false
            $0.path[id: 2] = .result(BugReportResultFeature.State())
        }

        #expect(store.state.path.count == 3)
    }
}
