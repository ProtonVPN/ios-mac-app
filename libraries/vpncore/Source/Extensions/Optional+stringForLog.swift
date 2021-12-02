//
//  Created on 2021-11-25.
//
//  Copyright (c) 2021 Proton AG
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

extension Optional where Wrapped: Any {
    
    /// Removes 'Optional' from the string and decodes Data to String.
    var stringForLog: String {
        guard let value = self else {
            return "null"
        }
        
        switch value {
        case let dataValue as Data:
            return String(data: dataValue, encoding: .utf8) ?? "-"
        default:
            return "\(value)"
        }
    }
}
