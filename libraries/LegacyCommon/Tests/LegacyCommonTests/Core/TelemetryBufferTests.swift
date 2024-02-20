//
//  Created on 19/01/2023.
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
import XCTest
@testable import LegacyCommon

extension DataManager {
    static func mock(data: Data?) -> DataManager {
        let data = LockIsolated(data)
        return DataManager(
            load: { _ in
                guard let value = data.value else { throw "No data specified" }
                return value
            },
            save: { newData, _ in data.setValue(newData) }
        )
    }
}

extension TelemetryBuffer.BufferedEvent {
    static func mock(id: UUID = UUID()) -> TelemetryBuffer.BufferedEvent {
        .init("".data(using: .utf8)!, id: id)
    }

    static var mockBufferedEvents: Data {
        let mock = [TelemetryBuffer.BufferedEvent.mock()]
        return try! JSONEncoder().encode(mock)
    }
}

class TelemetryBufferTests: XCTestCase {
    override static func setUp() {
        super.setUp()
    }

    // When initialized, buffer is loaded with events from storage
    func testBufferLoadsEventsFromMemory() async {
        await withDependencies {
            $0.dataManager = .mock(data: TelemetryBuffer.BufferedEvent.mockBufferedEvents)
            $0.date = .constant(Date())
        } operation: {
            let buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: .telemetryEvents)
            let count = await buffer.events.count
            XCTAssertEqual(count, 1)
        }
    }

    // When initialized, buffer is not loaded with events from storage
    func testBufferDoesntLoadEventsFromMemory() async {
        await withDependencies {
            $0.dataManager = .mock(data: TelemetryBuffer.BufferedEvent.mockBufferedEvents)
            $0.date = .constant(Date())
        } operation: {
            let buffer = await TelemetryBuffer(retrievingFromStorage: false, bufferType: .telemetryEvents)
            let count = await buffer.events.count
            XCTAssertEqual(count, 0)
        }
    }

    // When loading from storage, remove events older then a week (dependency is Date())
    func testBufferRemovesOldEventsWhenLoadingFromMemory() async {
        await withDependencies {
            $0.dataManager = .mock(data: TelemetryBuffer.BufferedEvent.mockBufferedEvents)
            $0.date = .constant(Date()
                .addingTimeInterval(TelemetryBuffer.Constants.maxStorageDuration)
                .addingTimeInterval(1))
        } operation: {
            let buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: .telemetryEvents)
            let count = await buffer.events.count
            XCTAssertEqual(count, 0)
        }
    }

    // Test that event is being saved to storage
    func testBufferSavesEvents() async throws {
        let dataManager: DataManager = .mock(data: nil)
        try await withDependencies {
            $0.dataManager = dataManager
            $0.date = .constant(Date())
        } operation: {
            let buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: .telemetryEvents)
            try await buffer.save(event: .init("test".data(using: .utf8)!, id: UUID()))
            let count = await buffer.events.count
            XCTAssertEqual(count, 1)
            let loaded = try! dataManager.load(URL(string: "some")!)
            let event = try! JSONDecoder().decode([TelemetryBuffer.BufferedEvent].self, from: loaded)
            XCTAssertEqual(String(data: event.first!.data, encoding: .utf8), "test")
        }
    }

    // Test that event is removed with a given UUID (dependency is UUID)
    func testBufferRemovesGivenEvent() async throws {
        let dataManager: DataManager = .mock(data: nil)
        try await withDependencies {
            $0.dataManager = dataManager
            $0.date = .constant(Date())
        } operation: {
            let buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: .telemetryEvents)
            try await buffer.save(event: .init("test".data(using: .utf8)!, id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!))
            try await buffer.save(event: .init("test2".data(using: .utf8)!, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
            let count = await buffer.events.count
            XCTAssertEqual(count, 2)
            await buffer.remove(event: .init("test2".data(using: .utf8)!, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
            let count2 = await buffer.events.count
            XCTAssertEqual(count2, 1)
            await buffer.remove(event: .init("test2".data(using: .utf8)!, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
            let count3 = await buffer.events.count
            XCTAssertEqual(count3, 1)
        }
    }

    // When asked for the oldest event, Buffer will return the first event from the list
    func testBufferReturnsFirstEvent() async {
        let mock: [TelemetryBuffer.BufferedEvent] = [.mock(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!),
                                                     .mock(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)]
        let data = try! JSONEncoder().encode(mock)

        await withDependencies {
            $0.dataManager = .mock(data: data)
            $0.date = .constant(Date())
        } operation: {
            let buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: .telemetryEvents)
            let event = await buffer.oldestEvent()
            XCTAssertEqual(event?.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        }
    }

    // Test that event is being saved to storage
    func testBufferSavesMax100Events() async throws {
        let mock = (0...TelemetryBuffer.Constants.maxStoredEvents).map { _ in TelemetryBuffer.BufferedEvent
            .mock()
        }
        let data = try! JSONEncoder().encode(mock)
        try await withDependencies {
            $0.dataManager = .mock(data: data)
            $0.date = .constant(Date())
        } operation: {
            let buffer = await TelemetryBuffer(retrievingFromStorage: true, bufferType: .telemetryEvents)
            let count1 = await buffer.events.count
            XCTAssertEqual(count1, 101)
            try await buffer.save(event: .init("test".data(using: .utf8)!, id: UUID()))
            let count2 = await buffer.events.count
            XCTAssertEqual(count2, TelemetryBuffer.Constants.maxStoredEvents)
        }
    }
}
