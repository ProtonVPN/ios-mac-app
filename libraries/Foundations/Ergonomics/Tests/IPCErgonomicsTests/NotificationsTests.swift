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

@Suite
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

// MARK: - SharedBuffer

@Suite
struct SharedBufferTests {
    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func firstWriteProducesSequenceOne() throws {
        let buf = try IPCHelperContext.sharedBuffer()
        let seq = try buf.write(Data([1, 2, 3]))
        #expect(seq == 1)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func sequenceIncrementsMonotonically() throws {
        let buf = try IPCHelperContext.sharedBuffer()
        for expected in UInt64(1) ... 5 {
            let seq = try buf.write(Data([UInt8(expected)]))
            #expect(seq == expected)
        }
    }

    // MARK: Seqlock read

    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func readWithMatchingSequenceReturnsData() throws {
        let buf = try IPCHelperContext.sharedBuffer()

        let payload = Data("seqlock".utf8)
        let seq = try buf.write(payload)

        #expect(buf.read(expectedSequence: seq) == payload)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func readWithStaleSequenceReturnsNil() throws {
        let buf = try IPCHelperContext.sharedBuffer()

        let staleSeq = try buf.write(Data("v1".utf8))
        _ = try buf.write(Data("v2".utf8))

        #expect(buf.read(expectedSequence: staleSeq) == nil)
    }

    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func readWithFutureSequenceReturnsNil() throws {
        let buf = try IPCHelperContext.sharedBuffer()

        let seq = try buf.write(Data([0]))

        #expect(buf.read(expectedSequence: seq + 1) == nil)
    }

    // MARK: Persistence across instances

    /// Simulates a process restart: a new SharedBuffer on the same file must be
    /// able to read whatever the previous instance wrote.
    @Test(.ipcContext(mmapFileURL: tmpURL()))
    func dataSurvivesReopeningFile() throws {
        let payload = Data("persistent".utf8)
        let seq: UInt64

        do {
            let writer = try IPCHelperContext.sharedBuffer()
            seq = try writer.write(payload)
        } // writer deinits (munmap)

        let reader = try IPCHelperContext.sharedBuffer()
        #expect(reader.read(expectedSequence: seq) == payload)
    }
}

// MARK: - Channel (integration, single-process Darwin notify)

@Suite
struct ChannelTests {
    // MARK: Post + observe

    /// Darwin notify works within a single process, so we can test the full
    /// post → observe path without a second process.
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func postAndObserveRoundTrip() async throws {
        let channel = try IPCHelperContext.channel(ofType: String.self)

        let (stream, continuation) = AsyncStream<Result<String, any Error>>.makeStream()
        let token = channel.observe { continuation.yield($0) }
        defer { _ = token }

        try channel.post("hello channel")

        let result = await stream.first
        #expect(try result?.get() == "hello channel")
    }

    // MARK: Token lifetime

    /// Dropping the token synchronously (before the post) must prevent delivery.
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func observerSilencedAfterTokenDropped() async throws {
        let channel = try IPCHelperContext.channel(ofType: String.self)

        _ = channel.observe { _ in
            Issue.record("Observer must not fire after its token is dropped")
        }

        try channel.post("should not arrive")
        // Suspend to let the main queue drain; the callback must not appear.
        try await Task.sleep(for: .milliseconds(100))
    }

    // MARK: Deeply nested enum round-trip

    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func deeplyNestedEnumRoundTrip() async throws {
        enum Severity: Codable, Equatable {
            case low
            case high(reason: String)
        }

        enum Detail: Codable, Equatable {
            case none
            case message(String)
            case structured(code: Int, severity: Severity)
        }

        enum Event: Codable, Equatable {
            case heartbeat
            case stateChange(newState: String, detail: Detail)
            case error(code: Int, detail: Detail, fatal: Bool)
        }

        struct Envelope: Codable, Equatable {
            let sequence: Int
            let event: Event
        }

        let cases: [Envelope] = [
            .init(sequence: 1, event: .heartbeat),
            .init(sequence: 2, event: .stateChange(newState: "connected", detail: .none)),
            .init(sequence: 3, event: .stateChange(newState: "degraded", detail: .message("latency spike"))),
            .init(sequence: 4, event: .error(code: 503, detail: .structured(code: 1, severity: .low), fatal: false)),
            .init(sequence: 5, event: .error(code: 500, detail: .structured(code: 9, severity: .high(reason: "timeout")), fatal: true)),
        ]

        let channel = try IPCHelperContext.channel(ofType: Envelope.self)

        for expected in cases {
            let (stream, continuation) = AsyncStream<Result<Envelope, any Error>>.makeStream()
            let token = channel.observe { continuation.yield($0) }
            defer { _ = token }

            try channel.post(expected)

            let result = await stream.first
            #expect(try result?.get() == expected, "Round-trip failed for sequence \(expected.sequence)")
        }
    }

    // MARK: includingCurrentValue

    /// Verifies that observe(includingCurrentValue:) delivers the value that was
    /// already in the buffer before the observation was registered — simulating
    /// the app process restarting while the NE is still running.
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func observeDeliversCurrentValueImmediately() async throws {
        struct State: Codable, Equatable { let status: String }

        // Writer posts before any observer exists.
        let writer = try IPCHelperContext.channel(ofType: State.self)
        try writer.post(State(status: "connected"))

        // A brand-new channel on the same file + notification, no new post.
        let reader = try IPCHelperContext.channel(ofType: State.self)

        let (stream, continuation) = AsyncStream<Result<State, any Error>>.makeStream()
        let sub = reader.observe(includingCurrentValue: true) { continuation.yield($0) }
        defer { _ = sub }

        let result = await stream.first
        #expect(try result?.get() == State(status: "connected"))
    }

    /// Verifies that stream(includingCurrentValue:) yields the buffered value as
    /// its first element, before any subsequent posts.
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func streamYieldsCurrentValueAsFirstElement() async throws {
        struct State: Codable, Equatable { let status: String }

        let writer = try IPCHelperContext.channel(ofType: State.self)
        try writer.post(State(status: "connected"))

        let reader = try IPCHelperContext.channel(ofType: State.self)
        let stream = reader.stream(includingCurrentValue: true)

        let first = await stream.first
        #expect(first == State(status: "connected"))
    }

    /// When the buffer is empty (no prior write), includingCurrentValue must
    /// not deliver a spurious nil or garbage value — the first delivery should
    /// only happen on the next real post.
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func includingCurrentValueIsNoOpWhenBufferIsEmpty() async throws {
        struct State: Codable, Equatable { let status: String }

        let channel = try IPCHelperContext.channel(ofType: State.self)

        let (stream, continuation) = AsyncStream<Result<State, any Error>>.makeStream()
        let sub = channel.observe(includingCurrentValue: true) { continuation.yield($0) }
        defer { _ = sub }

        // Post after registering — this must be the first (and only) delivery.
        try channel.post(State(status: "ready"))

        let result = await stream.first
        #expect(try result?.get() == State(status: "ready"))
    }

    // MARK: Task cancellation

    /// Verifies that cancelling the consuming Task terminates the stream
    /// immediately — without a new value needing to be posted first.
    ///
    /// If this test fails the stream is hanging until the next post, which
    /// means resources (notify token, mmap'd buffer) are leaked for the
    /// lifetime of that wait.
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func taskCancellationTerminatesStreamPromptly() async throws {
        struct Ping: Codable { let id: Int }

        let channel = try IPCHelperContext.channel(ofType: Ping.self)

        // No values will ever be posted — the task will be suspended in
        // `for await` indefinitely unless cancellation propagates correctly.
        let task = Task {
            let stream = channel.stream()
            for await _ in stream {}
        }

        // Let the task reach the suspended state inside `for await`.
        try await Task.sleep(for: .milliseconds(50))

        task.cancel()

        // Race task completion against a 500 ms timeout.
        // `try? Task.sleep` swallows CancellationError when the group is
        // cancelled after the first result arrives, keeping the group clean.
        let completedInTime = await withTaskGroup(of: Bool.self) { group in
            group.addTask { try? await Task.sleep(for: .milliseconds(500)); return false }
            group.addTask { await task.value; return true } // task should be cancelled already, so returning `true`
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        #expect(completedInTime, "Stream must terminate on task cancellation without waiting for a new value")
    }

    // MARK: Codable round-trip

    /// A non-trivial Codable type must survive encode → mmap → decode intact.
    @Test(.ipcContext(mmapFileURL: tmpURL(), notification: uniqueNotification()))
    func codableRoundTrip() async throws {
        struct Event: Codable, Equatable {
            let kind: String
            let value: Int
        }

        let channel = try IPCHelperContext.channel(ofType: Event.self)

        let (stream, continuation) = AsyncStream<Result<Event, any Error>>.makeStream()
        let token = channel.observe { continuation.yield($0) }
        defer { _ = token }

        let expected = Event(kind: "connected", value: 42)
        try channel.post(expected)

        let result = await stream.first
        #expect(try result?.get() == expected)
    }
}
