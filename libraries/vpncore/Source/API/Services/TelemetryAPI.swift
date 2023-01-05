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
    func flushEvent(event: ConnectionEvent)
}

public protocol TelemetryAPIFactory {
    func makeTelemetryAPI(networking: Networking) -> TelemetryAPI
}

class TelemetryAPIImplementation: TelemetryAPI {

    private let networking: Networking

    init(networking: Networking) {
        self.networking = networking
    }

    func flushEvent(event: ConnectionEvent) {
        let request = TelemetryRequest(event)
        switch event.event {
        case .vpnConnection(let timeInterval):
            log.debug("pj vpnConnection")
            log.debug("pj outcome: \(event.dimensions.outcome)")
            log.debug("pj time_to_connection: \(timeInterval)")
        case .vpnDisconnection(let timeInterval):
            log.debug("pj vpnDisconnection")
            log.debug("pj outcome: \(event.dimensions.outcome)")
            log.debug("pj session_length: \(timeInterval)")
        }
        networking.apiService.perform(request: request) { task, result in
            switch result {
            case .success:
                log.debug("Telemetry event was sent")
            case .failure(let error):
                log.debug("Failed to send a Telemetry event with error: \(error.localizedDescription)")
            }
        }
    }
}
