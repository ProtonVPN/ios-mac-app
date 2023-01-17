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

actor TelemetryBuffer {

    struct BufferedEvent: Codable {
        let id: UUID
        let timeStamp: TimeInterval
        let data: Data

        init(_ data: Data) {
            self.id = UUID()
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

    var events: [BufferedEvent] = []

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    let decoder = JSONDecoder()

    init() {
        Task {
            await retrieveFromStorage()
            await discardOutdatedEvents()
        }
    }

    func oldestEvent() -> BufferedEvent? {
        events.first
    }

    func discardOutdatedEvents() {
        // if it's older then a week, discard it
        let deadline = Date().timeIntervalSince1970 - 60 * 60 * 24 * 7 // a week
        events = events.filter { $0.timeStamp > deadline }
    }

    func save(event: BufferedEvent) {
        events.append(event)
        // remove the oldest events above the count of 100
        let removeCount = events.count - 100
        if removeCount > 0 {
            events.removeFirst(removeCount)
        }
        saveToStorage()
    }

    func remove(event: BufferedEvent) {
        guard let index = events.firstIndex(where: { storedEvent in
            storedEvent.id == event.id
        }) else { return }
        events.remove(at: index)
        saveToStorage()
    }

    func saveToStorage() {
        do {
            let data = try encoder.encode(events)
            try data.write(to: fileUrl)
        } catch {
            log.warning("Couldn't write Telemetry event to storage: \(error)", category: .telemetry)
        }
    }

    func retrieveFromStorage() {
        do {
            let encoded = try Data(contentsOf: fileUrl)
            let events = try decoder.decode([BufferedEvent].self, from: encoded)
            self.events = events
            log.debug("Retrieved \(events.count) events from storage", category: .telemetry)
        } catch {
            log.warning("Couldn't retrieve Telemetry events from storage: \(error)", category: .telemetry)
        }
    }

    var fileUrl: URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TelemetryEvents", isDirectory: false)
    }()
}
