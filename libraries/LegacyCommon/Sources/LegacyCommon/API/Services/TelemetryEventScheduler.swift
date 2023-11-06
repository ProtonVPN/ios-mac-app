//
//  Created on 09/11/2023.
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

import LocalFeatureFlags
import Foundation

class TelemetryEventScheduler {
    public typealias Factory = NetworkingFactory & PropertiesManagerFactory & TelemetryAPIFactory & TelemetrySettingsFactory

    private let factory: Factory

    private let isBusiness: Bool
    private let buffer: TelemetryBuffer
    private lazy var networking: Networking = factory.makeNetworking()
    private lazy var telemetrySettings: TelemetrySettings = factory.makeTelemetrySettings()
    private lazy var telemetryAPI: TelemetryAPI = factory.makeTelemetryAPI(networking: networking)

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    init(factory: Factory, isBusiness: Bool) async {
        self.factory = factory
        self.isBusiness = isBusiness
        self.buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: isBusiness ? .businessEvents : .telemetryEvents)
    }

    var telemetryUsageData: Bool {
        isBusiness ? telemetrySettings.businessEvents : telemetrySettings.telemetryUsageData
    }

    /// This should be the single point of reporting telemetry events. Before we do anything with the event,
    /// we need to check if the user agreed to collecting telemetry data.
    func report(event: any TelemetryEvent) throws {
        if telemetryUsageData {
            Task {
                await sendTelemetryEvent(event)
            }
        } else {
            throw "Didn't send Telemetry event, feature disabled"
        }
    }

    private func sendTelemetryEvent(_ event: any TelemetryEvent) async {
        await sendEvent(event)
    }

    /// Sends event to API or saves to buffer for sending later.
    ///
    /// We'll first check if we should save the events to storage in case that the network call fails.
    ///
    /// If we shouldn't, then we'll just try sending the event and log failure if the call fails.
    ///
    /// Otherwise we check if the buffer is not empty, if it isn't, save to to the end of the queue
    /// and try sending all the buffered events immediately after that.
    ///
    /// If the buffer is empty, try to send the event to out API, if it fails, save it to the buffer.
    private func sendEvent(_ event: any TelemetryEvent) async {
        guard LocalFeatureFlags.isEnabled(TelemetryFeature.useBuffer) else {
            do {
                try await telemetryAPI.flushEvent(event: event.toJSONDictionary(), isBusiness: isBusiness)
            } catch {
                log.debug("Failed to send a Telemetry event with error: \(error.localizedDescription). Didn't save to buffer because feature flag is disabled")
            }
            return
        }
        guard await buffer.events.isEmpty else {
            await scheduleEvent(event)
            await sendScheduledEvents()
            return
        }
        do {
            try await telemetryAPI.flushEvent(event: event.toJSONDictionary(), isBusiness: isBusiness)
        } catch {
            log.warning("Failed to send telemetry event, saving to storage: \(event)", category: .telemetry)
            await scheduleEvent(event)
        }
    }

    /// Save the event to local storage
    private func scheduleEvent(_ event: any TelemetryEvent) async {
        let bufferedEvent: TelemetryBuffer.BufferedEvent
        do {
            bufferedEvent = .init(try encoder.encode(event), id: UUID())
        } catch {
            log.warning("Failed to serialize telemetry event: \(event)", category: .telemetry)
            return
        }
        await buffer.save(event: bufferedEvent)
        log.debug("Telemetry event scheduled:\n\(String(data: bufferedEvent.data, encoding: .utf8)!)")
    }

    /// Send all telemetry events safely, if the closure won't throw an error, the buffer will purge its storage
    private func sendScheduledEvents() async {
        await buffer.scheduledEvents { [telemetryAPI] events in
            do {
                try await telemetryAPI.flushEvents(events: events, isBusiness: isBusiness)
            } catch {
                log.warning("Failed to send scheduled telemetry events, saving to storage: \(events)", category: .telemetry)
            }
        }
    }
}
