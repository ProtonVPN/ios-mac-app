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

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SearchStorage {
    public var clear: @Sendable () -> Void
    public var get: @Sendable () -> [String] = { [] }
    public var save: @Sendable (_ data: [String]) -> Void
}

extension SearchStorage: TestDependencyKey {
    public static var testValue: SearchStorage = {
        var storedData: [String] = []

        let storage = SearchStorage(
            clear: {
                storedData = []
            },
            get: {
                storedData
            },
            save: { data in
                storedData = data
            }
        )
        return storage
    }()
}

public extension DependencyValues {
    var searchStorage: SearchStorage {
        get { self[SearchStorage.self] }
        set { self[SearchStorage.self] = newValue }
    }
}
