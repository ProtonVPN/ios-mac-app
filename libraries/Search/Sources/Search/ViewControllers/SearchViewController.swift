//
//  Created on 02.03.2022.
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
import UIKit

final class SearchViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var noResultsView: NoResultsView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var placeholderView: PlaceholderView!

    // MARK: Properties

    var viewModel: SearchViewModel!

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupData()
    }

    private func setupUI() {
        baseViewStyle(view)
        baseViewStyle(tableView)
        baseViewStyle(searchBar)

        title = LocalizedString.searchTitle
    }

    private func setupData() {
        viewModel.delegate = self

        statusDidChange(status: viewModel.status)
    }
}

// MARK: Delegate

extension SearchViewController: SearchViewModelDelegate {
    func statusDidChange(status: SearchStatus) {
        placeholderView.isHidden = status != .placeholder
        activityIndicator.isHidden = status != .searching
        noResultsView.isHidden = status != .noResults
    }
}
