//
//  Created on 2022-01-11.
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

/// Struct for holding InputField that defines the field in the form and resulting value that can be changed by the user.
struct FormInputField: Equatable {
    let inputField: InputField
    var stringValue: String = ""
    var boolValue: Bool = false
    var hidden: Bool = false
}

extension FormInputField: Identifiable {
    var id: String {
        return inputField.id
    }
}
