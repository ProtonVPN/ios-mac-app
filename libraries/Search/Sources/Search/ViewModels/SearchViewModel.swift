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

protocol SearchViewModelDelegate: AnyObject {
    func statusDidChange(status: SearchStatus)
}

final class SearchViewModel {

    // MARK: Properties

    private let recentSearchesService: RecentSearchesService

    private(set) var status: SearchStatus {
        didSet {
            delegate?.statusDidChange(status: status)
        }
    }

    private(set) var data: [CountryViewModel]
    private(set) var mode: SearchMode
    private let constants: Constants
    private(set) var cities: [CityViewModel] = []

    weak var delegate: SearchViewModelDelegate?

    var numberOfCountries: Int {
        return constants.numberOfCountries
    }

    init(recentSearchesService: RecentSearchesService, data: [CountryViewModel], constants: Constants, mode: SearchMode) {
        self.data = data
        self.recentSearchesService = recentSearchesService
        self.mode = mode
        self.constants = constants

        let recent = recentSearchesService.get()
        status = recent.isEmpty ? .placeholder : .recentSearches(recent)

        self.cities = createCities(data: data)
    }

    // MARK: Actions

    func reload(data: [CountryViewModel], mode: SearchMode) {
        self.data = data
        self.mode = mode
        self.cities = createCities(data: data)
    }

    func clearRecentSearches() {
        recentSearchesService.clear()
        status = .placeholder
    }

    func search(searchText: String?) {
        guard let searchText = searchText, !searchText.isEmpty else {
            let recent = recentSearchesService.get()
            status = recent.isEmpty ? .placeholder : .recentSearches(recent)
            return
        }

        let filter = { (name: String) -> Bool in
            let normalizedSearchText = searchText.normalized
            let normalizedParts = name.components(separatedBy: CharacterSet.whitespaces).map({ $0.normalized })
            return normalizedParts.contains(where: { $0.starts(with: normalizedSearchText) })
        }

        var results: [SearchResult] = []
        let countries = data.filter({ filter($0.description) })

        switch mode {
        case let .standard(userTier):
            if !countries.isEmpty {
                results.append(SearchResult.countries(countries: countries))
            }

            let cities = self.cities.filter({ filter($0.name) || filter($0.country.description) }).sorted(by: { $0.name < $1.name })
            if !cities.isEmpty {
                results.append(SearchResult.cities(cities: cities))
            }

            for tier in ServerTier.sorted(by: userTier) {
                let tierServers = data.flatMap({ $0.getServers()[tier]?.filter({ filter($0.description) }) ?? [] })
                if !tierServers.isEmpty {
                    results.append(SearchResult.servers(tier: tier, servers: tierServers))
                }
            }

            if userTier == .free, !results.isEmpty {
                results.insert(SearchResult.upsell, at: 0)
            }

        case .secureCore:
            let servers = countries.flatMap({ $0.getServers().flatMap { $0.1 } })
            if !servers.isEmpty {
                results.append(SearchResult.secureCoreCountries(servers: servers))
            }
        }

        status = results.isEmpty ? .noResults : .results(results)
    }

    func saveSearch(searchText: String) {
        recentSearchesService.add(searchText: searchText)
    }

    private func createCities(data: [CountryViewModel]) -> [CityViewModel] {
        return data.flatMap { country -> [CityViewModel] in
            let servers = country.getServers().values.flatMap({ $0 }).filter({ !$0.torAvailable && !$0.city.isEmpty })
            let groups = Dictionary.init(grouping: servers, by: { $0.city })
            return groups.map({
                CityViewModel(name: $0.key, country: country, servers: $0.value)
            }).sorted(by: { $0.name < $1.name })
        }
    }
}
