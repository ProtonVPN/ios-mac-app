//
//  Created on 17/01/2023.
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
import Dependencies

actor TelemetryBuffer {
    struct Constants {
        static let maxStoredEvents = 100
        static let maxStorageDuration: TimeInterval = .days(7)
        static let measurementGroup: String = "vpn.any.connection"
    }
    @Dependency(\.dataManager) var dataManager
    @Dependency(\.date) var date

    var events: [BufferedEvent] = []

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    let decoder = JSONDecoder()

    enum BufferType: String {
        case telemetryEvents = "TelemetryEvents"
        case businessEvents = "BusinessEvents"
    }

    private let bufferType: BufferType

    init(retrievingFromStorage: Bool, bufferType: BufferType) async {
        self.bufferType = bufferType
        guard retrievingFromStorage else { return }
        retrieveFromStorage()
        discardOutdatedEvents()
    }

    func scheduledEvents(_ events: ([String: Any]) async throws -> Void) async {
        guard !self.events.isEmpty else {
            // Simply stop, don't invoke the handler
            log.info("No telemetry events scheduled", category: .telemetry)
            return
        }
        let tempEvents = self.events
        do {
            let all = allEvents()
            self.events = []
            try await events(all)
            try saveToStorage()
        } catch {
            log.warning("Failed to send scheduled telemetry events: \(error)", category: .telemetry)
            // we can get a telemetry event in the meantime, append to the existing (most likely empty) array
            self.events = tempEvents.appending(self.events)
        }
    }

    func oldestEvent() -> BufferedEvent? {
        events.first
    }

    func allEvents() -> [String: Any] {
        let events = events.compactMap {
            try? JSONSerialization.jsonObject(with: $0.data) as? JSONDictionary
        }
        return ["MeasurementGroup": Constants.measurementGroup,
                "EventInfo": events]
    }

    func discardOutdatedEvents() {
        // if it's older then a week, discard it
        let deadline = date.now.timeIntervalSince1970 - Constants.maxStorageDuration
        events = events.filter {
            $0.timeStamp >= deadline
        }
    }

    func save(event: BufferedEvent) throws {
        events.append(event)
        // remove the oldest events above the count of 100
        let removeCount = events.count - Constants.maxStoredEvents
        if removeCount > 0 {
            events.removeFirst(removeCount)
        }
        try saveToStorage()
    }

    func remove(event: BufferedEvent) {
        guard let index = events.firstIndex(where: { storedEvent in
            storedEvent.id == event.id
        }) else { return }
        events.remove(at: index)
        try? saveToStorage()
    }

    func saveToStorage() throws {
        do {
            let data = try encoder.encode(events)
            try dataManager.save(data, fileUrl)
        } catch {
            throw "Couldn't write Telemetry events to storage: \(error)"
        }
    }

    func retrieveFromStorage() {
        do {
            let encoded = try dataManager.load(fileUrl)
            let events = try decoder.decode([BufferedEvent].self, from: encoded)
            self.events = events
            log.debug("Retrieved \(events.count) events from storage", category: .telemetry)
        } catch {
            log.warning("Couldn't retrieve Telemetry events from storage: \(error)", category: .telemetry)
        }
    }

    lazy var fileUrl: URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent(bufferType.rawValue, isDirectory: false)
    }()
}

extension TelemetryBuffer {
    struct BufferedEvent: Codable {
        let id: UUID
        let timeStamp: TimeInterval
        let data: Data

        init(_ data: Data, id: UUID) {
            self.id = id
            self.timeStamp = Date().timeIntervalSince1970
            self.data = data
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(UUID.self, forKey: .id)
            self.timeStamp = try container.decode(TimeInterval.self, forKey: .timeStamp)
            self.data = try container.decode(Data.self, forKey: .data)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(timeStamp, forKey: .timeStamp)
            try container.encode(data, forKey: .data)
        }

        enum CodingKeys: String, CodingKey {
            case id
            case timeStamp
            case data
        }
    }
}
