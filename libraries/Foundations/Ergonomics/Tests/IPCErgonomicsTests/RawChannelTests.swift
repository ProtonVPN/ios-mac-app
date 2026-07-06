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
        let writer = try IPCHelperContext.writer(ofType: IPCTestPayload.self)
        let reader = try IPCHelperContext.reader(ofType: IPCTestPayload.self)

        writer.mutate { ptr in
            ptr.bytes_transferred = 1024.5
            ptr.timestamp = 42
            ptr.peer_migrations = 2
        }

        let snapshot = try reader.read()
        #expect(snapshot.bytes_transferred == 1024.5)
        #expect(snapshot.timestamp == 42)
        #expect(snapshot.peer_migrations == 2)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func readBeforeAnyWriteReturnsZeroedMemory() throws {
        let reader = try IPCHelperContext.reader(ofType: IPCTestPayload.self)
        // mmap is zero-initialised; seqlock = 0 (even), so read should succeed.
        let snapshot = try reader.read()
        #expect(snapshot.bytes_transferred == 0)
        #expect(snapshot.peer_migrations == 0)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func observeFields() async throws {
        let writer = try IPCHelperContext.writer(ofType: IPCTestPayload.self)
        let reader = try IPCHelperContext.reader(ofType: IPCTestPayload.self)

        let stream = reader.stream(forField: \.peer_migrations)
        writer.mutate { $0.peer_migrations = 1337 }

        let value = await stream.first
        #expect(value == 1337)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func streamFullPayloadObservesClosureMutation() async throws {
        let writer = try IPCHelperContext.writer(ofType: IPCTestPayload.self)
        let reader = try IPCHelperContext.reader(ofType: IPCTestPayload.self)

        let stream = reader.stream()
        writer.mutate { ptr in
            ptr.bytes_transferred = 512.0
            ptr.timestamp = 7
        }

        let snapshot = await stream.first
        #expect(snapshot?.bytes_transferred == 512.0)
        #expect(snapshot?.timestamp == 7)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func zeroClearsPayload() throws {
        let writer = try IPCHelperContext.writer(ofType: IPCTestPayload.self)
        let reader = try IPCHelperContext.reader(ofType: IPCTestPayload.self)

        writer.mutate { ptr in
            ptr.bytes_transferred = 1024.5
            ptr.timestamp = 42
            ptr.peer_migrations = 7
        }
        #expect(try reader.read().peer_migrations == 7)

        writer.zero()

        let snapshot = try reader.read()
        #expect(snapshot.bytes_transferred == 0)
        #expect(snapshot.timestamp == 0)
        #expect(snapshot.peer_migrations == 0)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func payloadOffsetMatchesCLayout() throws {
        // RawChannel.payloadOffset must equal C's offsetof(IPCTestRegion, payload).
        // Both sides must agree or reads/writes will target the wrong memory.
        //
        // IPCSharedHeader = { _Atomic uint64_t seqlock } = 8 bytes.
        // IPCTestPayload starts with `double` (8-byte aligned), so no padding needed.
        // Expected offset: 8.
        let channel = try IPCHelperContext.reader(ofType: IPCTestPayload.self)
        #expect(channel.payloadOffset == 8)
        #expect(MemoryLayout<IPCTestPayload>.alignment <= 8)
    }

    @Test
    func coalescedViewsStayIsolatedAndDemuxByGeneration() async throws {
        // Two channels viewing one shared buffer at different sub-region offsets.
        // Each has its own seqlock, both share a single notification and demux by generation count.
        let regionStride = MemoryLayout<IPCTestRegion>.stride
        let region = try IPCNotifications.SharedRegion<FileBackedRegion>(
            .init(fileURL: tmpURL(), size: regionStride * 2)
        )
        let notification = uniqueNotification()
        // A writer/reader endpoint per sub-region, all over the one shared region.
        let writerA = IPCNotifications.RawChannel<IPCTestPayload, WriterRole, FileBackedRegion>(
            notification: notification, seqlockRegion: region.seqlockRegion(at: 0, length: regionStride)
        )
        let readerA = IPCNotifications.RawChannel<IPCTestPayload, ReaderRole, FileBackedRegion>(
            notification: notification, seqlockRegion: region.seqlockRegion(at: 0, length: regionStride)
        )
        let writerB = IPCNotifications.RawChannel<IPCTestPayload, WriterRole, FileBackedRegion>(
            notification: notification, seqlockRegion: region.seqlockRegion(at: regionStride, length: regionStride)
        )
        let readerB = IPCNotifications.RawChannel<IPCTestPayload, ReaderRole, FileBackedRegion>(
            notification: notification, seqlockRegion: region.seqlockRegion(at: regionStride, length: regionStride)
        )

        // Isolation: a write through one view never bleeds into the other's sub-region.
        writerA.mutate { $0.timestamp = 111 }
        #expect(try readerA.read().timestamp == 111)
        #expect(try readerB.read().timestamp == 0)

        writerB.mutate { $0.timestamp = 222 }
        #expect(try readerA.read().timestamp == 111)
        #expect(try readerB.read().timestamp == 222)

        // Generation demux: a sibling's write doesn't reach this view's stream — only A's own write does, and the
        // latest value is delivered.
        let aStream = readerA.stream()
        writerB.mutate { $0.timestamp = 444 }
        writerA.mutate { $0.timestamp = 555 }
        let delivered = await aStream.first
        #expect(delivered?.timestamp == 555)
    }
}
