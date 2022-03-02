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

final class RecentSearchesService {
    private var data: [String] = []
    private let key = "RECENT_SEARCHES"
    private let maxCount = 5

    init() {
        guard let serialized = UserDefaults.standard.data(forKey: key), let data = try? JSONDecoder().decode([String].self, from: serialized) else {
            return
        }

        self.data = data
    }

    func get() -> [String] {
        return data
    }

    func add(search: String) {
        if data.count >= maxCount {
            data = data.dropLast()
        }

        data.insert(search, at: 0)
        save()
    }

    func clear() {
        data = []
        save()
    }

    private func save() {
        guard !data.isEmpty else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        guard let serialized = try? JSONEncoder().encode(data) else {
            return
        }

        UserDefaults.standard.set(serialized, forKey: key)
    }
}
