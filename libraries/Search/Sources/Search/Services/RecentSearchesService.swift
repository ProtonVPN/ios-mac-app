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
    private let maxCount = 5
    private let storage: SearchStorage

    init(storage: SearchStorage) {
        self.storage = storage
        self.data = storage.get()
    }

    func get() -> [String] {
        return data
    }

    func add(searchText: String) {
        data.removeAll(where: { $0 == searchText })

        if data.count >= maxCount {
            data = data.dropLast()
        }

        data.insert(searchText, at: 0)
        save()
    }

    func clear() {
        data = []
        save()
    }

    private func save() {
        guard !data.isEmpty else {
            storage.clear()
            return
        }

        storage.save(data: data)
    }
}
