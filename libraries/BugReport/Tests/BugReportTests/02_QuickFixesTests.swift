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
final class QuickFixesTests: XCTestCase {

    private let delegate = MockBugReportDelegate(model: .mock)

    private var categoryWithQuickFixes: BugReport.Category {
        delegate.model.categories.first!
    }

    func testButtonOpensContactForm() async throws {
        let category = categoryWithQuickFixes

        let store = TestStore(
            initialState: QuickFixesFeature.State(category: category),
            reducer: QuickFixesFeature()
        )

        // Open form
        await store.send(.next, assert: { resultState in
            resultState.contactFormState = ContactFormFeature.State(fields: category.inputFields, category: category.label)
        })

        // Go back
        await store.send(.contactFormDeselected, assert: { resultState in
            resultState.contactFormState = nil
        })
    }

}
