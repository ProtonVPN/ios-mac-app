//
//  Created on 2022-01-28.
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

import XCTest
@testable import BugReport

@available(iOS 14.0, macOS 11.0, *)
final class MacBugReportViewModelTests: XCTestCase {
        
    func testSequence() throws {
        let model = BugReportModel.mock
        let bugReportDelegate = MockBugReportDelegate(model: model)
        CurrentEnv.bugReportDelegate = bugReportDelegate
        
        // Categories
        let viewModel = MacBugReportViewModel(model: model)
        XCTAssertEqual(viewModel.page, .categories([]))
        XCTAssertEqual(viewModel.step, 1)
        
        // Suggestions
        let category = model.categories.first!
        viewModel.categorySelected(category)
        XCTAssertEqual(viewModel.page, .suggestions(category))
        XCTAssertEqual(viewModel.step, 2)
        
        // Back button, and then forward to Suggestions
        viewModel.back()
        XCTAssertEqual(viewModel.page, .categories([]))
        XCTAssertEqual(viewModel.step, 1)
        viewModel.categorySelected(category)
        
        // Form
        let formViewModel = FormViewModel(fields: category.inputFields, category: "Category")
        viewModel.suggestionsFinished()
        XCTAssertEqual(viewModel.page, .form(formViewModel))
        XCTAssertEqual(viewModel.step, 3)
        
        // Back button, and then forward to Form
        viewModel.back()
        XCTAssertEqual(viewModel.page, .suggestions(category))
        viewModel.categorySelected(category)
        
        // Error result
        viewModel.form?.sendResult = .failure(NSError(domain: "", code: 1, userInfo: nil))
        XCTAssertEqual(viewModel.page, .result(nil))
        
        // Back from error page
        viewModel.back()
        XCTAssertEqual(viewModel.page, .form(formViewModel))
        
        // Success result
        viewModel.form?.sendResult = .success(Void())
        XCTAssertEqual(viewModel.page, .result(nil))
        
    }
    
    func testSequenceWithoutSuggestions() throws {
        let model = BugReportModel.mock
        let bugReportDelegate = MockBugReportDelegate(model: model)
        CurrentEnv.bugReportDelegate = bugReportDelegate
                
        // Categories
        let viewModel = MacBugReportViewModel(model: model)
        XCTAssertEqual(viewModel.page, .categories([]))
        
        // Back button doesn't work here
        viewModel.back()
        XCTAssertEqual(viewModel.page, .categories([]))
        
        // Not Suggestions but Form
        let category = model.categories.last! // Last category in test json is without suggestions
        let formViewModel = FormViewModel(fields: category.inputFields, category: "Category")
        viewModel.categorySelected(category)
        XCTAssertEqual(viewModel.page, .form(formViewModel))
        
        // Back button goes to Categories
        viewModel.back()
        XCTAssertEqual(viewModel.page, .categories([]))        
    }
    
    
}

// Compare Page enums without checking what's inside.
@available(iOS 14.0, macOS 11.0, *)
extension MacBugReportViewModel.Page: Equatable {
    static public func == (lhs: MacBugReportViewModel.Page, rhs: MacBugReportViewModel.Page) -> Bool {
        switch (lhs, rhs) {
        case (.categories, .categories): return true
        case (.suggestions, .suggestions): return true
        case (.form, .form): return true
        case (.result, .result): return true
        default: return false
        }
    }
}
