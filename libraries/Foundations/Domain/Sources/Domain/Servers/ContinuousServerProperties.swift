//
//  Created on 21/12/2023.
//
//  Copyright (c) 2023 Proton AG
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

public struct ContinuousServerProperties: CustomStringConvertible {
    public let serverId: String
    public let load: Int
    public let score: Double
    public let status: Int

    public var description: String {
        return "ServerID: \(serverId)\n"
            + "Load: \(load)\n"
            + "Score: \(score)\n"
            + "Status: \(status)"
    }

    public init(serverId: String, load: Int, score: Double, status: Int) {
        self.serverId = serverId
        self.load = load
        self.score = score
        self.status = status
    }
}
