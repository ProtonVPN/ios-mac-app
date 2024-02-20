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

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    init(factory: Factory, isBusiness: Bool) async {
        self.factory = factory
        self.isBusiness = isBusiness
        self.buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: isBusiness ? .businessEvents : .telemetryEvents)
    }

    private var telemetryUsageData: Bool {
        isBusiness ? telemetrySettings.businessEvents : telemetrySettings.telemetryUsageData
    }

    /// This should be the single point of reporting telemetry events. Before we do anything with the event,
    /// we need to check if the user agreed to collecting telemetry data or the B2B requires it.
    func report(event: any TelemetryEvent) async throws {
        if telemetryUsageData {
            try await sendEvent(event)
        } else {
            throw "Didn't send \(isBusiness ? "Business" : "Telemetry") event, feature disabled"
        }
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
    private func sendEvent(_ event: any TelemetryEvent) async throws {
        guard LocalFeatureFlags.isEnabled(TelemetryFeature.useBuffer) else {
            do {
                let response = try await telemetryAPI.flushEvent(event: event.toJSONDictionary(), isBusiness: isBusiness)
                log.info("Telemetry event sent with response code: \(response.code). Event: \(event)", category: .telemetry)
            } catch {
                log.debug("Failed to send a Telemetry event with error: \(error.localizedDescription). Didn't save to buffer because feature flag is disabled")
            }
            return
        }
        guard await buffer.events.isEmpty else {
            try await scheduleEvent(event)
            await sendScheduledEvents()
            return
        }
        do {
            let response = try await telemetryAPI.flushEvent(event: event.toJSONDictionary(), isBusiness: isBusiness)
            log.info("Telemetry event sent with response code: \(response.code). Event: \(event)", category: .telemetry)
        } catch {
            log.warning("Failed to send telemetry event, saving to storage: \(event)", category: .telemetry)
            try await scheduleEvent(event)
        }
    }

    /// Save the event to local storage
    private func scheduleEvent(_ event: any TelemetryEvent) async throws {
        let bufferedEvent: TelemetryBuffer.BufferedEvent
        do {
            bufferedEvent = .init(try encoder.encode(event), id: UUID())
            try await buffer.save(event: bufferedEvent)
        } catch {
            throw "Failed scheduling telemetry event: \(event), error: \(error)"
        }
        log.debug("Telemetry event scheduled:\n\(String(data: bufferedEvent.data, encoding: .utf8)!)")
    }

    /// Send all telemetry events safely, if the closure won't throw an error, the buffer will purge its storage
    private func sendScheduledEvents() async {
        await buffer.scheduledEvents { [telemetryAPI] events in
            do {
                let response = try await telemetryAPI.flushEvents(events: events, isBusiness: isBusiness)
                log.info("Telemetry events sent with response code: \(response.code). Events: \(events)", category: .telemetry)
            } catch {
                log.warning("Failed to send scheduled telemetry events, leaving in storage: \(events)", category: .telemetry)
            }
        }
    }
}
