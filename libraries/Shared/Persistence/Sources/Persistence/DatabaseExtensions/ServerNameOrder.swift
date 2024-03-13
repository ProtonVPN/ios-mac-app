//
//  Created on 16/01/2024.
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

import Foundation

import GRDB

import Strings

// TODO: Currently not in use because it is slow, and flimsy (crashes for server names like US-GA#29-TOR)
// We could instead alter the logicals table to store the broken up server name in parts and/or create an index on those
var prependServerName: ([DatabaseValue]) throws -> String = { dbValues in
    if dbValues.isEmpty {
        throw ServerNameError.missingArgument
    }

    guard let name = String.fromDatabaseValue(dbValues[0]) else {
        throw ServerNameError.invalidArgument(value: dbValues[0])
    }

    let parts = name.components(separatedBy: "#")

    guard parts.count == 2, let number = Int(parts[1]) else {
        #if DEBUG
        throw ServerNameError.invalidServerName(name: name)
        #else
        return name
        #endif
    }

    return parts[0] + String(format: "%08d", number)
}

enum ServerNameError: Error {
    case missingArgument
    case invalidArgument(value: DatabaseValue)
    case invalidServerName(name: String)
}

let sortableServerName = DatabaseFunction(
    "SORTABLE_SERVER_NAME",
    argumentCount: 1,
    pure: true,
    function: prependServerName
)
