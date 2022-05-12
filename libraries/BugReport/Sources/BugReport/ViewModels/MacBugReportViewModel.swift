//
//  Created on 2022-01-21.
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
import SwiftUI

@available(iOS 14.0, *)
final class MacBugReportViewModel: ObservableObject {

    @Published var page: Page
    @Published var updateIsAvailable: Bool

    var model: BugReportModel
    var category: Category?
    var form: FormViewModel?

    var steps: UInt = 3
    var step: UInt {
        switch page {
        case .categories:   return 1
        case .suggestions:  return 2
        case .form:         return 3
        case .result:       return 0
        }
    }

    init(model: BugReportModel) {
        self.model = model
        page = .categories(model.categories)
        updateIsAvailable = false
    }

    enum Page {
        case categories([Category])
        case suggestions(Category)
        case form(FormViewModel)
        case result(Error?)
    }

    // Actions

    func categorySelected(_ category: Category) {
        self.category = category
        guard !(category.suggestions?.isEmpty ?? true) else {
            form = makeFormViewModel(with: category.inputFields)
            push(.form(form!))
            return
        }
        push(.suggestions(category))
    }

    func suggestionsFinished() {
        guard let category = category else {
            return
        }
        form = makeFormViewModel(with: category.inputFields)
        push(.form(form!))
    }

    func resultReceived() {
        guard let form = self.form, form.shouldShowResultView else {
            return
        }
        self.push(.result(form.sendResultError))
    }

    func back() {
        switch page {
        case .result:
            guard let form = form else { return }
            pop(.form(form))

        case .form:
            guard let category = category, let suggestions = category.suggestions, !suggestions.isEmpty else {
                pop(.categories(model.categories))
                return
            }
            pop(.suggestions(category))

        case .suggestions:
            pop(.categories(model.categories))

        case .categories:
            break // It's already the first screen
        }
    }

    private func makeFormViewModel(with fields: [InputField]) -> FormViewModel {
        let viewModel = FormViewModel(fields: category?.inputFields ?? [], category: category?.label)
        viewModel.sendResultChanged = { [weak self] in
            guard let `self` = self else { return }
            withAnimation {
                self.resultReceived()
            }
        }
        return viewModel
    }

    // Navigation animations:
    // change animation type if user presses Back button.

    var navigationType: NavigationType = .pop

    enum NavigationType {
        case push
        case pop
    }

    private func push(_ page: Page) {
        navigationType = .push
        self.page = page
    }

    private func pop(_ page: Page) {
        navigationType = .pop
        self.page = page
    }

}
