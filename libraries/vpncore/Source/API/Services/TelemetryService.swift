//
//  Created on 13/12/2022.
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
import LocalFeatureFlags

enum TelemetryFeature: String, FeatureFlag {
    var category: String {
        "Telemetry"
    }

    var feature: String {
        rawValue
    }

    case telemetryOptIn = "TelemetryOptIn"
}

class TelemetryService {
    public typealias Factory = NetworkingFactory

    private let networking: Networking

    let buffer: TelemetryBuffer = TelemetryBuffer()
    lazy var telemetryAPI: TelemetryAPI = TelemetryAPI(networking: networking)

    public convenience init(_ factory: Factory) {
        self.init(networking: factory.makeNetworking())
    }

    init(networking: Networking) {
        self.networking = networking
    }

    func report(event: ConnectionEvent) async {
        guard isEnabled(TelemetryFeature.telemetryOptIn) else { return }

        await buffer.scheduleEvent(event: event)

        if buffer.shouldFlushEvents {
            await telemetryAPI.flushEvents(buffer: buffer)
            await buffer.removeSentEvents()
        }
    }
}

class TelemetryAPI {

    private let networking: Networking

    init(networking: Networking) {
        self.networking = networking
    }

    func flushEvents(buffer: TelemetryBuffer) async {
        let events = buffer.events
        let request = TelemetryRequest(events)
        do {
            try await withCheckedThrowingContinuation { continuation in
                networking.apiService.perform(request: request) { task, result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            await buffer.markEventsAsSent(events: events)
        } catch {
            // failed sending the events, do nothing
        }
    }
}

class TelemetryBuffer {

    var shouldFlushEvents: Bool = false // decide based on the time since last flush and the amount of events generated

    var events: [ConnectionEvent] = []

    func scheduleEvent(event: ConnectionEvent) async {
        // append to the list of events to send
        // Q: How do we store/queue the events? Just on a file on disk?
    }

    func markEventsAsSent(events: [ConnectionEvent]) async {
        // append to the list of events to send
    }

    func removeSentEvents() async {
        // remove events marked as sent
    }
}
