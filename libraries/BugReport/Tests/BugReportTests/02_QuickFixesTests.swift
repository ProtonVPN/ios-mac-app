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

@testable import BugReportShared
import ComposableArchitecture
import Testing

@MainActor
struct QuickFixesTests {
    private let delegate = MockBugReportDelegate(model: .mock)

    private var categoryWithQuickFixes: BugReportShared.Category {
        delegate.model.categories.first!
    }

    private var categoryWithoutQuickFixes: BugReportShared.Category {
        delegate.model.categories.last!
    }

    @Test("No logic is present in quick fixes apart binding")
    func selectedCategory() async {
        let store = TestStore(
            initialState: QuickFixesFeature.State(category: categoryWithQuickFixes),
            reducer: { QuickFixesFeature() }
        )

        await store.send(.binding(.set(\.category, categoryWithoutQuickFixes))) {
            $0.category = categoryWithoutQuickFixes
        }
    }
}
