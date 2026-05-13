//
//  Created on 19/05/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

// TODO: Rework this with ProTUN and previous IP validation we had thanks to Network.framework
public struct ConnectionDetailsMessage {
    public let exitIp: String
    public let deviceIp: String?
    public let deviceCountry: String?
}

extension ConnectionDetailsMessage: Sendable {}
extension ConnectionDetailsMessage: Equatable {}
