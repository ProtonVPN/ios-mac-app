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

class ConnectionTimer: TelemetryTimer {

    private var startedConnectingDate: Date?
    private var stoppedConnectionDate: Date?
    private var startedConnectionDate: Date?

    func updateConnectionStarted(timeInterval: TimeInterval) {
        startedConnectionDate = Date(timeIntervalSince1970: timeInterval)
    }

    func markStartedConnecting() {
        guard startedConnectingDate == nil else { return }
        startedConnectingDate = Date()
    }

    func markFinishedConnecting() {
        guard startedConnectionDate == nil else { return }
        startedConnectionDate = Date()
    }

    func markConnectionStoped() {
        stoppedConnectionDate = Date()
    }

    func connectionDuration() -> TimeInterval? {
        guard let startedConnectionDate,
              let stoppedConnectionDate else { return nil }
        self.startedConnectionDate = nil
        self.stoppedConnectionDate = nil
        return stoppedConnectionDate.timeIntervalSince(startedConnectionDate)
    }

    func timeToConnect() -> TimeInterval? {
        guard let startedConnectingDate,
              let startedConnectionDate else { return nil }

        self.startedConnectingDate = nil
        return startedConnectionDate.timeIntervalSince(startedConnectingDate)
    }
}
