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
import ProtonCore_Utilities

public protocol TelemetryAPI {
    func flushEvent(event: JSONDictionary) async throws
}

public protocol TelemetryAPIFactory {
    func makeTelemetryAPI(networking: Networking) -> TelemetryAPI
}

class TelemetryAPIImplementation: TelemetryAPI {

    private let networking: Networking

    init(networking: Networking) {
        self.networking = networking
    }

    func flushEvent(event: JSONDictionary) async throws {
        let request = TelemetryRequest(event)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            self.networking.apiService.perform(request: request) { task, result in
                switch result {
                case .success:
                    continuation.resume()
                    log.debug("Telemetry event was sent")
                case .failure(let error):
                    continuation.resume(throwing: error)
                    log.debug("Failed to send a Telemetry event with error: \(error.localizedDescription)")
                }
            }
        }
    }
}
