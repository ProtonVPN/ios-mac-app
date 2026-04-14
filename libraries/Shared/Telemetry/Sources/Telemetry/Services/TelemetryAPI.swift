//
//  Created on 22/12/2022.
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

import ProtonCoreUtilities

import Dependencies
import DependenciesMacros

import CommonNetworking

@DependencyClient
public struct TelemetryAPIClient: Sendable {
    public var flushEvent: @Sendable (_ event: [String: Any], _ isBusiness: Bool) async throws -> TelemetryResponse
    public var flushMultipleEvents: @Sendable (_ events: [String: Any], _ isBusiness: Bool) async throws -> TelemetryResponse
}

extension TelemetryAPIClient: DependencyKey {
    public static let liveValue = TelemetryAPIClient { event, isBusiness in
        @Dependency(\.networking) var networking
        return try await networking.perform(request: TelemetryRequest(event, isBusiness: isBusiness))
    } flushMultipleEvents: { events, isBusiness in
        @Dependency(\.networking) var networking
        return try await networking.perform(request: TelemetryRequestMultiple(events, isBusiness: isBusiness))
    }

    public static var testValue: TelemetryAPIClient {
        TelemetryAPIClient { _, _ in
            TelemetryResponse(code: 1000)
        } flushMultipleEvents: { _, _ in
            TelemetryResponse(code: 1000)
        }
    }
}

public extension DependencyValues {
    var telemetryAPIClient: TelemetryAPIClient {
        get { self[TelemetryAPIClient.self] }
        set { self[TelemetryAPIClient.self] = newValue }
    }
}
