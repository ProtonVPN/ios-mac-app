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

import Dependencies
import Foundation
import Persistence
import Search

extension Search.Configuration {
    init() {
        @Dependency(\.serverRepository) var repository
        self.init(constants: Constants(numberOfCountries: repository.countryCount()))
    }
}

extension SearchStorage: @retroactive DependencyKey {
    private static let key = "RECENT_SEARCHES"

    public static var liveValue: SearchStorage = {
        @Dependency(\.storage) var storage
        let searchStorage = SearchStorage(
            clear: {
                storage.removeObject(forKey: key)
            },
            get: {
                (try? storage.get([String].self, forKey: key)) ?? []
            },
            save: { data in
                try? storage.set(data, forKey: key)
            }
        )
        return searchStorage
    }()
}
