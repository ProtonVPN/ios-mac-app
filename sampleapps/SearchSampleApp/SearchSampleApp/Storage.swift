//
//  Created on 08.03.2022.
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
import Search

final class Storage: SearchStorage {
    private let key = "RECENT_SEARCHES"

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func get() -> [String] {
        guard let serialized = UserDefaults.standard.data(forKey: key), let data = try? JSONDecoder().decode([String].self, from: serialized) else {
            return []
        }

        return data
    }

    func save(data: [String]) {
        guard let serialized = try? JSONEncoder().encode(data) else {
            return
        }

        UserDefaults.standard.set(serialized, forKey: key)
    }
}
