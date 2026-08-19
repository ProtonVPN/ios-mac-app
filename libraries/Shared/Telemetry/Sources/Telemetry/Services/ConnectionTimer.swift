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

protocol TelemetryTimer {
    func updateConnectionStarted(_ date: Date?)
    func markStartedConnecting()
    func markFinishedConnecting()
    func markConnectionStopped()
    func connectionDuration(connectedDate: Date) -> TimeInterval
    var timeConnecting: TimeInterval { get throws }
}

class ConnectionTimer: TelemetryTimer {
    enum Error: Swift.Error {
        case missingStartedConnectingDate
    }

    private var startedConnectingDate: Date?
    private var startedConnectionDate: Date?
    private var stoppedConnectionDate: Date?

    init() {}

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

    func connectionDuration(connectedDate: Date) -> TimeInterval {
        Date().timeIntervalSince(connectedDate)
    }

    var timeConnecting: TimeInterval {
        get throws {
            guard let startedConnectingDate else { throw Error.missingStartedConnectingDate }
            return Date().timeIntervalSince(startedConnectingDate)
        }
    }
}
