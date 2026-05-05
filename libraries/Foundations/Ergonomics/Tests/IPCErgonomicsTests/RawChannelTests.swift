//
//  Created on 03/04/2026.
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

import Foundation
@testable import IPCErgonomics
import IPCErgonomicsTestSupport
import Testing

private func tmpURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

private func uniqueNotification() -> IPCNotifications.Notification {
    .init(name: "ch.protonvpn.test.raw.\(UUID().uuidString)")
}

struct RawChannelTests {
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func mutateAndReadRoundTrip() throws {
        let channel = try IPCHelperContext.rawChannel(ofType: IPCTestPayload.self)

        channel.mutate { ptr in
            ptr.bytes_transferred = 1024.5
            ptr.timestamp = 42
            ptr.peer_migrations = 2
        }

        let snapshot = try channel.read()
        #expect(snapshot.bytes_transferred == 1024.5)
        #expect(snapshot.timestamp == 42)
        #expect(snapshot.peer_migrations == 2)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func mutateFieldsAndReadRoundTrip() throws {
        let channel = try IPCHelperContext.rawChannel(ofType: IPCTestPayload.self)

        try channel.mutate(\.bytes_transferred, to: 1024.5)
        try channel.mutate(\.timestamp, to: 42)
        try channel.mutate(\.peer_migrations, to: 2)

        let snapshot = try channel.read()
        #expect(snapshot.bytes_transferred == 1024.5)
        #expect(snapshot.timestamp == 42)
        #expect(snapshot.peer_migrations == 2)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func readBeforeAnyWriteReturnsZeroedMemory() throws {
        let channel = try IPCHelperContext.rawChannel(ofType: IPCTestPayload.self)
        // mmap is zero-initialised; seqlock = 0 (even), so read should succeed.
        let snapshot = try channel.read()
        #expect(snapshot.bytes_transferred == 0)
        #expect(snapshot.peer_migrations == 0)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func observeFields() async throws {
        let channel = try IPCHelperContext.rawChannel(ofType: IPCTestPayload.self)

        let stream = channel.stream(forField: \.peer_migrations)
        try channel.mutate(\.peer_migrations, to: 1337)

        let value = await stream.first
        #expect(value == 1337)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func streamFullPayloadObservesClosureMutation() async throws {
        let channel = try IPCHelperContext.rawChannel(ofType: IPCTestPayload.self)

        let stream = channel.stream()
        channel.mutate { ptr in
            ptr.bytes_transferred = 512.0
            ptr.timestamp = 7
        }

        let snapshot = await stream.first
        #expect(snapshot?.bytes_transferred == 512.0)
        #expect(snapshot?.timestamp == 7)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func onUnrelatedFieldChangeCalledWhenOtherFieldMutated() async throws {
        let channel = try IPCHelperContext.rawChannel(ofType: IPCTestPayload.self)

        let unrelatedChanges = AsyncStream<Void> { continuation in
            let token = channel.observeField(
                \.peer_migrations,
                handler: { _ in
                    Issue.record("handler must not fire for an unrelated field mutation")
                },
                onUnrelatedFieldChange: {
                    continuation.yield(())
                }
            )
            let box = IPCNotifications.TokenBox(token)
            continuation.onTermination = { _ in box.token = nil }
        }

        try channel.mutate(\.bytes_transferred, to: 99.0)

        let received: Void? = await unrelatedChanges.first
        #expect(received != nil)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func payloadOffsetMatchesCLayout() throws {
        // RawChannel.payloadOffset must equal C's offsetof(IPCTestRegion, payload).
        // Both sides must agree or reads/writes will target the wrong memory.
        //
        // IPCSharedHeader = { _Atomic uint64_t seqlock } = 8 bytes.
        // IPCTestPayload starts with `double` (8-byte aligned), so no padding needed.
        // Expected offset: 8.
        let channel = try IPCHelperContext.rawChannel(ofType: IPCTestPayload.self)
        #expect(channel.payloadOffset == 8)
        #expect(MemoryLayout<IPCTestPayload>.alignment <= 8)
    }
}
