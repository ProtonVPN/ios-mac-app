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

    private(set) var recentSearches: [String]

    weak var delegate: SearchViewModelDelegate?

    init(recentSearchesService: RecentSearchesService) {
        self.recentSearchesService = recentSearchesService

        let recent = recentSearchesService.get()
        recentSearches = recent
        status = recent.isEmpty ? .placeholder : .recentSearches
    }

    // MARK: Actions

    func clearRecentSearches() {
        recentSearchesService.clear()
        recentSearches = recentSearchesService.get()
        status = .placeholder
    }
}
