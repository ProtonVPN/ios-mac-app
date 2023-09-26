//
//  Created on 20/12/2022.
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
import DictionaryCoder

public struct ConnectionEvent: TelemetryEvent, Encodable {
    public typealias CodingKeys = TelemetryKeys

    public var measurementGroup: String = "vpn.any.connection"
    public let event: Event
    public let dimensions: ConnectionDimensions

    public var values: Values {
        switch event {
        case .vpnConnection(let timeToConnection):
            return .init(timeToConnection: timeToConnection)
        case .vpnDisconnection(let sessionLength):
            return .init(sessionLength: sessionLength)
        }
    }

    public init(event: Event, dimensions: ConnectionDimensions) {
        self.event = event
        self.dimensions = dimensions
    }
    
    public enum Event: Encodable {
        case vpnConnection(timeToConnection: TimeInterval)
        case vpnDisconnection(sessionLength: TimeInterval)

        var rawValue: String {
            switch self {
            case .vpnConnection:
                return Self.CodingKeys.vpnConnection.rawValue
            case .vpnDisconnection:
                return Self.CodingKeys.vpnDisconnection.rawValue
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        enum CodingKeys: String, CodingKey {
            case vpnConnection = "vpn_connection"
            case vpnDisconnection = "vpn_disconnection"
        }
    }

    public struct Values: Encodable {
        let timeToConnection: Int? // milliseconds
        let sessionLength: Int? // milliseconds

        enum CodingKeys: String, CodingKey {
            case timeToConnection = "time_to_connection"
            case sessionLength = "session_length"
        }

        init(timeToConnection: TimeInterval? = nil, sessionLength: TimeInterval? = nil) {
            self.timeToConnection = Self.inMilliseconds(timeToConnection)
            self.sessionLength = Self.inMilliseconds(sessionLength)
        }

        private static func inMilliseconds(_ timeInterval: TimeInterval?) -> Int? {
            guard let timeInterval else { return nil }
            return Int(timeInterval * 1000)
        }
    }
}
