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
    func setupTableView() {
        tableView.register(RecentSearchCell.nib, forCellReuseIdentifier: RecentSearchCell.identifier)
        tableView.register(CountryCell.nib, forCellReuseIdentifier: CountryCell.identifier)
        tableView.register(ServerCell.nib, forCellReuseIdentifier: ServerCell.identifier)
        tableView.register(UpsellCell.nib, forCellReuseIdentifier: UpsellCell.identifier)
        tableView.register(CityCell.nib, forCellReuseIdentifier: CityCell.identifier)
        tableView.register(SearchSectionHeaderView.nib, forHeaderFooterViewReuseIdentifier: SearchSectionHeaderView.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel.status {
        case .noResults, .placeholder:
            return 0
        case let .recentSearches(data):
            return data.count
        case let .results(data):
            return data[section].count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.status {
        case .noResults, .placeholder:
            assertionFailure("Invalid usage")
            return UITableViewCell()
        case let .recentSearches(data):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: RecentSearchCell.identifier) as? RecentSearchCell else {
                assertionFailure("Invalid configuration")
                return UITableViewCell()
            }
            cell.title = data[indexPath.row]
            return cell
        case let .results(data):
            let item = data[indexPath.section]
            switch item {
            case let .countries(countries: countries):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: CountryCell.identifier) as? CountryCell else {
                    assertionFailure("Invalid configuration")
                    return UITableViewCell()
                }
                cell.searchText = searchBar.text
                cell.viewModel = countries[indexPath.row]
                return cell
            case let .servers(tier: _, servers: servers):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: ServerCell.identifier) as? ServerCell else {
                    assertionFailure("Invalid configuration")
                    return UITableViewCell()
                }
                cell.searchText = searchBar.text
                cell.viewModel = servers[indexPath.row]
                return cell
            case let .secureCoreCountries(servers: servers):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: ServerCell.identifier) as? ServerCell else {
                    assertionFailure("Invalid configuration")
                    return UITableViewCell()
                }
                cell.searchText = searchBar.text
                cell.viewModel = servers[indexPath.row]
                return cell
            case let .cities(cities: cities):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: CityCell.identifier) as? CityCell else {
                    assertionFailure("Invalid configuration")
                    return UITableViewCell()
                }
                cell.searchText = searchBar.text
                cell.viewModel = cities[indexPath.row]
                return cell
            case .upsell:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: UpsellCell.identifier) as? UpsellCell else {
                    assertionFailure("Invalid configuration")
                    return UITableViewCell()
                }
                cell.numberOfCountries = viewModel.numberOfCountries
                return cell
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        switch viewModel.status {
        case .noResults, .placeholder:
            return 0
        case .recentSearches:
            return 1
        case let .results(data):
            return data.count
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.status {
        case .noResults, .placeholder:
            return nil
        case let .recentSearches(data):
            recentSearchesHeaderView.count = data.count
            return recentSearchesHeaderView
        case let .results(data):
            guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: SearchSectionHeaderView.identifier) as? SearchSectionHeaderView else {
                fatalError("Invalid configuration")
            }
            headerView.item = data[section]
            return headerView
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch viewModel.status {
        case .noResults, .placeholder:
            break
        case let .recentSearches(data):
            searchBar.text = data[indexPath.row]
            viewModel.search(searchText: data[indexPath.row])
        case let .results(data):
            let item = data[indexPath.section]
            switch item {
            case let .countries(countries):
                delegate?.userDidSelectCountry(model: countries[indexPath.row])
            case .upsell:
                delegate?.userDidRequestPlanPurchase()
            case .servers, .secureCoreCountries, .cities:
                break
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel.status {
        case .noResults, .placeholder, .recentSearches:
            return UITableView.automaticDimension
        case let .results(data):
            let item = data[section]
            switch item {
            case .upsell:
                return 0
            case .countries, .servers, .secureCoreCountries, .cities:
                return UITableView.automaticDimension
            }
        }
    }
}
