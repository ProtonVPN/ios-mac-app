//
//  Created on 07/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import XCTest

extension UITraitCollection {
    static let darkMode = UITraitCollection(userInterfaceStyle: .dark)
    static let lightMode = UITraitCollection(userInterfaceStyle: .light)
}

enum Trait {
    case light
    case dark

    var rawValue: UITraitCollection {
        switch self {
        case .light:
            return .lightMode
        case .dark:
            return .darkMode
        }
    }

    var name: String {
        switch self {
        case .light:
            return "light"
        case .dark:
            return "dark"
        }
    }
}
