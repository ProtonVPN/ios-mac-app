//
//  Created on 14/11/2024.
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

public struct ServerNameComponents {
    public let name: String
    public let sequence: Int?

    public init(name: String) {
        let nameArray = name.split(separator: "#")
        guard nameArray.count == 2 else {
            self.name = name
            self.sequence = nil
            return
        }
        let serverName = String(nameArray[0])
        // some of the server sequence numbers might have the trailing "-TOR" - we strip it
        guard let numberString = nameArray[1].split(separator: "-").first, let serverNumber = Int(String(numberString)) else {
            self.name = serverName
            sequence = nil
            return
        }
        self.name = serverName
        self.sequence = serverNumber
    }
}
