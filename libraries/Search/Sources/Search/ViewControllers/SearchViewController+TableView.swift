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

// MARK: Table view delegate

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel.status {
        case .searching, .noResults, .placeholder:
            return 0
        case let .recentSearches(data):
            return data.count
        case let .results(data):
            return data[section].count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.status {
        case .searching, .noResults, .placeholder:
            fatalError("Invalid usage")
        case let .recentSearches(data):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: RecentSearchCell.identifier)  as? RecentSearchCell else {
                fatalError("Invalid configuration")
            }
            cell.title = data[indexPath.row]
            return cell
        case let .results(data):
            let item = data[indexPath.section]
            switch item {
            case let .countries(tupples):
                let (country, servers) = tupples[indexPath.row]
                guard let cell = tableView.dequeueReusableCell(withIdentifier: CountryCell.identifier)  as? CountryCell else {
                    fatalError("Invalid configuration")
                }
                cell.viewModel = delegate?.createCountryCellViewModel(country: country, servers: servers)
                return cell
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        switch viewModel.status {
        case .searching, .noResults, .placeholder:
            return 0
        case .recentSearches:
            return 1
        case let .results(data):
            return data.count
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.status {
        case .searching, .noResults, .placeholder, .results:
            return nil
        case let .recentSearches(data):
            recentSearchesHeaderView.count = data.count
            return recentSearchesHeaderView
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch viewModel.status {
        case .searching, .noResults, .placeholder:
            break
        case let .recentSearches(data):
            searchBar.text = data[indexPath.row]
            viewModel.search(searchText: data[indexPath.row])
        case let .results(data):
            let item = data[indexPath.section]
            switch item {
            case let .countries(items):
                let (country, servers) = items[indexPath.row]
                if let model = delegate?.createCountryCellViewModel(country: country, servers: servers) {
                    delegate?.userDidSelectCountry(model: model)
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch viewModel.status {
        case .searching, .noResults, .placeholder, .recentSearches:
            return UITableView.automaticDimension
        case .results:
            return 72
        }
    }
}
