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
import Search
import vpncore
import UIKit

extension Configuration {
    init() {
        self.init(colors: Colors(background: .backgroundColor(), text: .normalTextColor(), brand: .brandColor(), weakText: .weakTextColor(), separator: .normalSeparatorColor(), secondaryBackground: .secondaryBackgroundColor(), iconWeak: .iconWeak()), constants: Constants(numberOfCountries: AccountPlan.plus.countriesCount, numberOfServers: AccountPlan.plus.serversCount))
    }
}

protocol SearchStorageFactory: AnyObject {
    func makeSearchStorage() -> SearchStorage
}

final class SearchModuleStorage: SearchStorage {
    private let storage: Storage
    private let key = "RECENT_SEARCHES"

    init(storage: Storage) {
        self.storage = storage
    }

    func clear() {
        storage.removeObject(forKey: key)
    }

    func get() -> [String] {
        return storage.getDecodableValue([String].self, forKey: key) ?? []
    }

    func save(data: [String]) {
        storage.setEncodableValue(data, forKey: key)
    }
}
