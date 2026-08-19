//
//  Created on 17/08/2026 by Max Kupetskyi.
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

import Ergonomics
import Foundation
@testable import Telemetry
import Testing

/// `toJSONDictionary()` turns an event into the dictionary the API layer sends as a JSON body. The values it produces
/// have to keep the types the API expects, and it has to leave absent values out instead of sending null.
struct TelemetryEventJSONTests {
    /// An event with one property per type the telemetry models use, so a single event covers all of them.
    private struct SampleEvent: TelemetryEvent {
        struct Values: Encodable {
            let count: Int
            let ratio: Double
            let absent: Int?
        }

        struct Dimensions: Encodable {
            let name: String
            let enabled: Bool
        }

        let measurementGroup = "vpn.any.sample"
        let event = "sample_event"
        let values: Values
        let dimensions: Dimensions
    }

    /// An event whose values cannot be written as JSON, which is the only way `toJSONDictionary()` can fail.
    private struct UnencodableEvent: TelemetryEvent {
        struct Values: Encodable {
            let ratio: Double
        }

        let measurementGroup = "vpn.any.unencodable"
        let event = "unencodable_event"
        let values = Values(ratio: .infinity)
        let dimensions = [String: String]()
    }

    /// An event with an unset optional dimension, which the models send as "n/a" through `NAEncodable`.
    private struct OptionalDimensionEvent: TelemetryEvent {
        struct Dimensions: Encodable {
            @NAEncodable var count: Int?

            enum CodingKeys: String, CodingKey {
                case count
            }
        }

        let measurementGroup = "vpn.any.optional"
        let event = "optional_event"
        let values = [String: String]()
        let dimensions: Dimensions
    }

    private static let sample = SampleEvent(
        values: .init(count: 42, ratio: 1.5, absent: nil),
        dimensions: .init(name: "sample", enabled: true)
    )

    @Test
    func `event fills the four top level keys the API expects`() throws {
        let dictionary = Self.sample.toJSONDictionary()

        #expect(Set(dictionary.keys) == ["MeasurementGroup", "Event", "Values", "Dimensions"])
        #expect(dictionary["MeasurementGroup"] as? String == "vpn.any.sample")
        #expect(dictionary["Event"] as? String == "sample_event")
        _ = try #require(dictionary["Values"] as? JSONDictionary)
        _ = try #require(dictionary["Dimensions"] as? JSONDictionary)
    }

    @Test
    func `values keep their number, string and boolean types`() throws {
        let dictionary = Self.sample.toJSONDictionary()
        let values = try #require(dictionary["Values"] as? JSONDictionary)
        let dimensions = try #require(dictionary["Dimensions"] as? JSONDictionary)

        #expect(values["count"] as? Int == 42)
        #expect(values["ratio"] as? Double == 1.5)
        #expect(dimensions["name"] as? String == "sample")
        #expect(dimensions["enabled"] as? Bool == true)
    }

    @Test
    func `absent values are left out instead of being sent as null`() throws {
        let values = try #require(Self.sample.toJSONDictionary()["Values"] as? JSONDictionary)

        #expect(!values.keys.contains("absent"))
        #expect(!values.values.contains { $0 is NSNull })
    }

    @Test
    func `an unset optional dimension is sent as n slash a`() throws {
        let event = OptionalDimensionEvent(dimensions: .init(count: nil))
        let dimensions = try #require(event.toJSONDictionary()["Dimensions"] as? JSONDictionary)

        #expect(dimensions["count"] as? String == "n/a")
    }

    @Test
    func `the dictionary can be written back out as JSON`() throws {
        let dictionary = Self.sample.toJSONDictionary()

        #expect(JSONSerialization.isValidJSONObject(dictionary))
        #expect(try !JSONSerialization.data(withJSONObject: dictionary).isEmpty)
    }

    @Test
    func `an event that cannot be written as JSON gives an empty dictionary`() {
        #expect(UnencodableEvent().toJSONDictionary().isEmpty)
    }

    @Test
    func `a connection event keeps its milliseconds as an integer`() throws {
        let dictionary = ConnectionEvent.connectionMock1.toJSONDictionary()
        let values = try #require(dictionary["Values"] as? JSONDictionary)

        #expect(dictionary["Event"] as? String == "vpn_connection")
        #expect(values["time_to_connection"] as? Int == 123_000)
        #expect(!values.keys.contains("session_length"))
    }
}
