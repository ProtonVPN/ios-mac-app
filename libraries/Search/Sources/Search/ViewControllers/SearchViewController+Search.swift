//
//  Created on 03.03.2022.
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
import Strings

// MARK: Search bar delegate

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.search(searchText: searchText)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
        _ = searchBar.resignFirstResponder()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        _ = searchBar.resignFirstResponder()
    }

    func reload() {
        viewModel.search(searchText: searchBar.text)
    }
}

// MARK: Recent searches delegate

extension SearchViewController: RecentSearchesHeaderViewDelegate {
    func userDidRequestClear() {
        let alert = UIAlertController(title: nil, message: Localizable.searchRecentClearTitle, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localizable.searchRecentClearCancel, style: .default))
        alert.addAction(UIAlertAction(title: Localizable.searchRecentClearContinue, style: .default) { [weak self] _ in
            self?.viewModel.clearRecentSearches()
        })

        present(alert, animated: true, completion: nil)
    }
}
