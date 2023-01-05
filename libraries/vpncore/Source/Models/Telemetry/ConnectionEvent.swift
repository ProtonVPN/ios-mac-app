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

public struct ConnectionEvent: Encodable, TelemetryEvent {
    var measurementGroup: String = "vpn.ios.connection"
    let event: ConnectionEventType
    let dimensions: TelemetryDimensions

    init(event: ConnectionEventType, dimensions: TelemetryDimensions) {
        self.event = event
        self.dimensions = dimensions
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(measurementGroup, forKey: .measurementGroup)
        try container.encode(event.rawValue, forKey: .event)
        try container.encode(dimensions, forKey: .dimensions)
        try container.encode(event.values, forKey: .values)
    }

    enum CodingKeys: String, CodingKey {
        case measurementGroup = "MeasurementGroup"
        case event = "Event"
        case values = "Values"
        case dimensions = "Dimensions"
    }

    func toJSONDictionary() -> JSONDictionary {
        guard let encoded = try? JSONEncoder().encode(self),
              let dict = encoded.jsonDictionary else { return [:] }
        return dict
    }
}

// swiftlint:disable nesting

enum ConnectionEventType: Encodable {
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

    enum CodingKeys: String, CodingKey {
        case vpnConnection = "vpn_connection"
        case vpnDisconnection = "vpn_disconnection"
    }

    struct Value: Encodable {
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

    var values: Value {
        switch self {
        case .vpnConnection(let timeToConnection):
            return .init(timeToConnection: timeToConnection)
        case .vpnDisconnection(let sessionLength):
            return .init(sessionLength: sessionLength)
        }
    }
}

// swiftlint:enable nesting
