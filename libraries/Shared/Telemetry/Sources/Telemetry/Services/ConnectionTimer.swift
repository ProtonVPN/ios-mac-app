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

public protocol TelemetryTimer {
    func updateConnectionStarted(_ date: Date?)
    func markStartedConnecting()
    func markFinishedConnecting()
    func markConnectionStopped()
    func connectionDuration(connectedDate: Date) -> TimeInterval
    var timeConnecting: TimeInterval { get throws }
}

public class ConnectionTimer: TelemetryTimer {
    enum Error: Swift.Error {
        case missingStartedConnectionDate
        case missingStartedConnectingDate
        case missingStoppedConnectionDate
    }

    private var startedConnectingDate: Date?
    private var startedConnectionDate: Date?
    private var stoppedConnectionDate: Date?

    public init() {}

    public func updateConnectionStarted(_ date: Date?) {
        startedConnectionDate = date ?? startedConnectionDate
    }

    public func markStartedConnecting() {
        startedConnectingDate = Date()
    }

    public func markFinishedConnecting() {
        startedConnectionDate = Date()
    }

    public func markConnectionStopped() {
        stoppedConnectionDate = Date()
    }

    public func connectionDuration(connectedDate: Date) -> TimeInterval {
        return Date().timeIntervalSince(connectedDate)
    }

    public var timeConnecting: TimeInterval {
        get throws {
            guard let startedConnectingDate else { throw Error.missingStartedConnectingDate }
            return Date().timeIntervalSince(startedConnectingDate)
        }
    }
}
