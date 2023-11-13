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

public protocol TelemetryAPI {
    func flushEvent(event: [String: Any], isBusiness: Bool) async throws
    func flushEvents(events: [String: Any], isBusiness: Bool) async throws
}

public protocol TelemetryAPIFactory {
    func makeTelemetryAPI(networking: Networking) -> TelemetryAPI
}

class TelemetryAPIImplementation: TelemetryAPI {

    private let networking: Networking

    init(networking: Networking) {
        self.networking = networking
    }

    func flushEvent(event: [String: Any], isBusiness: Bool) async throws {
        _ = try await networking.apiService.perform(request: TelemetryRequest(event, isBusiness: isBusiness))
    }

    func flushEvents(events: [String: Any], isBusiness: Bool) async throws {
        _ = try await networking.apiService.perform(request: TelemetryRequestMultiple(events, isBusiness: isBusiness))
    }
}
