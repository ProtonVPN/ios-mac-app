//
//  Created on 27/03/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Ergonomics
import Foundation
@testable import IPCErgonomics
import Testing

// MARK: - Helpers

private func tmpURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

private func uniqueNotification() -> IPCNotifications.Notification {
    .init(name: "ch.protonvpn.test.ipc.\(UUID().uuidString)")
}

// MARK: - MmapBuffer

struct MmapBufferTests {
    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func roundTrip() throws {
        let url = try IPCHelperContext.url()

        let buf = try MmapBuffer(path: url.path(), size: 256)
        let original = Data("hello mmap".utf8)

        try buf.write(data: original, toByteOffset: 0)
        let result = buf.read(fromByteOffset: 0, count: original.count)

        #expect(result == original)
    }

    /// Writing at an offset must leave bytes before it untouched.
    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func writeAtOffsetDoesNotClobberHeader() throws {
        let url = try IPCHelperContext.url()

        let buf = try MmapBuffer(path: url.path(), size: 256)
        try buf.write(data: Data([0xDE, 0xAD]), toByteOffset: 0)
        let payload = Data("payload".utf8)
        try buf.write(data: payload, toByteOffset: 12)

        #expect(buf.read(fromByteOffset: 0, count: 2) == Data([0xDE, 0xAD]))
        #expect(buf.read(fromByteOffset: 12, count: payload.count) == payload)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func writeTooLargeThrows() throws {
        let url = try IPCHelperContext.url()

        let buf = try MmapBuffer(path: url.path(), size: 64)
        // 60 bytes at offset 12 → reaches byte 72, past the 64-byte limit.
        let oversized = Data(repeating: 0xFF, count: 60)
        #expect {
            try buf.write(data: oversized, toByteOffset: 12)
        } throws: { error in
            guard case .tooLargePayload = error as? MmapBufferError else { return false }
            return true
        }
    }
}

// MARK: - Observation lifetime

struct ObservationLifetimeTests {
    private final class Sentinel {}

    @Test
    func cancelReleasesHandlerCaptures() {
        weak var weakObservation: IPCNotifications.Observation?
        weak var weakSentinel: Sentinel?

        let queue = DispatchQueue(label: "test.observation.\(UUID().uuidString)")

        do {
            var sentinel = Sentinel()
            weakSentinel = sentinel

            let token = IPCNotifications.observeRawState(
                uniqueNotification(),
                queue: queue
            ) { _ in
                _ = sentinel
            }

            let observation = token.observation()
            weakObservation = observation

            observation.cancel()
        }

        // blocks & drain the serial queue so any deferred block deallocation triggered
        // by notify_cancel has completed before we check the weak refs.
        queue.sync {}

        #expect(weakObservation == nil, "Observation must deinit after cancel + scope exit")
        #expect(weakSentinel == nil, "notify handler closure (and its captures) must be released after cancel")
    }

    @Test
    func scopeExitReleasesHandlerCaptures() {
        weak var weakObservation: IPCNotifications.Observation?
        weak var weakSentinel: Sentinel?

        let queue = DispatchQueue(label: "test.observation.\(UUID().uuidString)")

        do {
            var sentinel = Sentinel()
            weakSentinel = sentinel

            let token = IPCNotifications.observeRawState(
                uniqueNotification(),
                queue: queue
            ) { _ in
                _ = sentinel
            }

            let observation = token.observation()
            weakObservation = observation
            withExtendedLifetime(observation) {}
        }

        // blocks & drain the serial queue so any deferred block deallocation triggered
        // by notify_cancel has completed before we check the weak refs.
        queue.sync {}

        #expect(weakObservation == nil, "Observation must deinit on scope exit")
        #expect(weakSentinel == nil, "notify handler closure (and its captures) must be released on scope exit")
    }
}
