//
//  Created on 2023-05-09.
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
final class WhatsTheIssueFeatureTests: XCTestCase {

    private let delegate = MockBugReportDelegate(model: .mock)

    private var categoryWithQuickFixes: BugReport.Category {
        delegate.model.categories.first!
    }

    private var categoryWithoutQuickFixes: BugReport.Category {
        delegate.model.categories.last!
    }

    // This depends on categories preset in BugReportModel.mock. First one has to have quick fixes.
    func testCategorySelectionShowsQuickFixesIfPossible() async throws {
        let store = TestStore(
            initialState: WhatsTheIssueFeature.State(categories: delegate.model.categories),
            reducer: WhatsTheIssueFeature()
        )

        let category = categoryWithQuickFixes
        await store.send(.categorySelected(category), assert: { resultState in
            resultState.quickFixesState = QuickFixesFeature.State(category: category)
        })

        await store.send(.quickFixesDeselected, assert: { resultState in
            resultState.quickFixesState = nil
        })
    }

    // This depends on categories preset in BugReportModel.mock. Last one has to have no quick fixes.
    func testCategorySelectionShowsFormIfNoQuickFixesProvided() async throws {
        let store = TestStore(
            initialState: WhatsTheIssueFeature.State(categories: delegate.model.categories),
            reducer: WhatsTheIssueFeature()
        )

        let category = categoryWithoutQuickFixes
        await store.send(.categorySelected(category), assert: { resultState in
            resultState.contactFormState = ContactFormFeature.State(fields: category.inputFields, category: category.label)
        })
        await store.send(.contactFormDeselected, assert: { resultState in
            resultState.contactFormState = nil
        })
    }
}
