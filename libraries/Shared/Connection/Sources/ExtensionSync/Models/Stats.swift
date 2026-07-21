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

public extension LocalAgent {
    struct Stats: Codable {
        public let bytesReceived: UInt64?
        public let bytesSent: UInt64?
        public let maliciousBlocked: UInt64?
        public let adsBlocked: UInt64?
        public let trackersBlocked: UInt64?
        public let adultContentBlocked: UInt64?
        public let dataSaved: UInt64?

        public init(
            bytesReceived: UInt64?,
            bytesSent: UInt64?,
            maliciousBlocked: UInt64?,
            adsBlocked: UInt64?,
            trackersBlocked: UInt64?,
            adultContentBlocked: UInt64?,
            dataSaved: UInt64?
        ) {
            self.bytesReceived = bytesReceived
            self.bytesSent = bytesSent
            self.maliciousBlocked = maliciousBlocked
            self.adsBlocked = adsBlocked
            self.trackersBlocked = trackersBlocked
            self.adultContentBlocked = adultContentBlocked
            self.dataSaved = dataSaved
        }
    }
}

extension LocalAgent.Stats: Sendable {}
