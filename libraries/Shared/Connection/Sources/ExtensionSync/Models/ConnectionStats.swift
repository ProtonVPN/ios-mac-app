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

import Foundation

public extension LocalAgent {
    struct ConnectionStats: Codable {
        public let timestampMs: Int64
        public let receivedBytes: UInt64
        public let sentBytes: UInt64
        public let timeSinceLastHandshake: TimeInterval
        public let estimatedLoss: Float
        public let estimatedRoundTripTime: TimeInterval

        public init(
            timestampMs: Int64,
            receivedBytes: UInt64,
            sentBytes: UInt64,
            timeSinceLastHandshake: TimeInterval,
            estimatedLoss: Float,
            estimatedRoundTripTime: TimeInterval
        ) {
            self.timestampMs = timestampMs
            self.receivedBytes = receivedBytes
            self.sentBytes = sentBytes
            self.timeSinceLastHandshake = timeSinceLastHandshake
            self.estimatedLoss = estimatedLoss
            self.estimatedRoundTripTime = estimatedRoundTripTime
        }
    }
}

extension LocalAgent.ConnectionStats: Sendable {}
