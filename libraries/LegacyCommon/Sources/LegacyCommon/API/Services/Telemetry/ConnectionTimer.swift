//
//  Created on 09/01/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Ergonomics

class ConnectionTimer: TelemetryTimer {

    private var startedConnectingDate: Date?
    private var startedConnectionDate: Date?
    private var stoppedConnectionDate: Date?

    func updateConnectionStarted(_ date: Date?) {
        startedConnectionDate = date ?? startedConnectionDate
    }

    func markStartedConnecting() {
        startedConnectingDate = Date()
    }

    func markFinishedConnecting() {
        startedConnectionDate = Date()
    }

    func markConnectionStopped() {
        stoppedConnectionDate = Date()
    }

    var connectionDuration: TimeInterval {
        get throws {
            guard let startedConnectionDate else { throw "Missing startedConnectionDate" }
            guard let stoppedConnectionDate else { throw "Missing stoppedConnectionDate" }
            return stoppedConnectionDate.timeIntervalSince(startedConnectionDate)
        }
    }

    var timeToConnect: TimeInterval {
        get throws {
            guard let startedConnectingDate else { throw "Missing startedConnectingDate" }
            guard let startedConnectionDate else { throw "Missing startedConnectionDate" }
            return startedConnectionDate.timeIntervalSince(startedConnectingDate)
        }
    }

    var timeConnecting: TimeInterval {
        get throws {
            guard let startedConnectingDate else { throw "Missing startedConnectingDate" }
            return Date().timeIntervalSince(startedConnectingDate)
        }
    }
}
