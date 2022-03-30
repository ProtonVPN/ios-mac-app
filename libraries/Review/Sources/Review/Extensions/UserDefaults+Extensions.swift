//
//  Created on 29.03.2022.
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

extension UserDefaults {
    func date(forKey defaultName: String) -> Date? {
        guard let value = object(forKey: defaultName) as? TimeInterval else {
            return nil
        }

        return Date(timeIntervalSince1970: value)
    }

    func set(_ value: Date?, forKey defaultName: String) {
        guard let value = value else {
            removeObject(forKey: defaultName)
            return
        }

        set(value.timeIntervalSince1970, forKey: defaultName)
    }
}
