//
//  Created on 17/04/2024.
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

struct LokiPushEntry: Codable {
    let streams: [LokiStream]
}

struct LokiStream: Codable {
    let stream: MetricsLabel
    let values: [[LokiCodable]]
}

struct MetricsLabel: Codable {
    let workflow: String
    let sli: String
    let environment: String
    let platform: String
    let product: String
}

struct Metadata: Codable {
    let id: String
    let os_version: String
    let app_version: String
    let build_id: String
}

//  METRICS CODABLE
struct LoginMetrics: Codable {
    let duration: String
    let status: String
}

struct FailureMetrics: Codable {
    let status: String
}

//  CODING OF LOKI VALUES
struct LokiCodable: Codable {
    private let value: Any

    init<T: Codable>(_ value: T) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try (value as! Encodable).encode(to: encoder)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        }
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
}
