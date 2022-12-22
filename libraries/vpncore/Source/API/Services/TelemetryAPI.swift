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

class TelemetryAPI {

    private let networking: Networking

    init(networking: Networking) {
        self.networking = networking
    }

    func flushEvent(event: ConnectionEvent) {
        let request = TelemetryRequest(event)
        networking.apiService.perform(request: request) { task, result in
            switch result {
            case .success:
                log.debug("Telemetry event was sent")
            case .failure(let error):
                log.debug("Failed to send a Telemetry event with error: \(error.localizedDescription)")
            }

            if let parameters = request.parameters as? [String: Any] {
                let pretty = parameters.json(prettyPrinted: true)
                log.debug("Telemetry event:\n\(pretty)")
            }
        }
    }
}
