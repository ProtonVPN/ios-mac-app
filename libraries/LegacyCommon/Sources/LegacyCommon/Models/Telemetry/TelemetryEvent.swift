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
fileprivate let encoder = DictionaryEncoder()

public protocol TelemetryEvent: Encodable {
    associatedtype Event: Encodable
    associatedtype Dimensions: Encodable
    associatedtype Values: Encodable
    
    var measurementGroup: String { get }
    var event: Event { get }
    var values: Values { get }
    var dimensions: Dimensions { get }
}

public enum TelemetryKeys: String, CodingKey {
    case measurementGroup = "MeasurementGroup"
    case event = "Event"
    case values = "Values"
    case dimensions = "Dimensions"
}

extension TelemetryEvent {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TelemetryKeys.self)

        try container.encode(measurementGroup, forKey: .measurementGroup)
        try container.encode(values, forKey: .values)
        try container.encode(event, forKey: .event)
        try container.encode(dimensions, forKey: .dimensions)
    }

    public func toJSONDictionary() -> JSONDictionary {
        let result = (try? encoder.encode(self)) ?? [:]
        return result.mapValues { $0 as AnyObject }
    }
}
