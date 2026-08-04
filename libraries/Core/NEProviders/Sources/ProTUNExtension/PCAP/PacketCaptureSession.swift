//
//  Created on 20/04/2026.
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

import AsyncAlgorithms
import Clocks
import Dependencies
import Domain
import Foundation
import os
import protun

struct PacketCaptureSession {
    static let pcapPathExtension: String = "pcap"
    private static let timerInterval: Duration = .minutes(1)
    private static let timerTolerance: Duration = .seconds(1)

    struct PcapFileHandle: Equatable {
        let startDate: Date
        let url: URL
    }

    enum State: Equatable {
        case idle
        case recording(PcapFileHandle)
        case finished(duration: TimeInterval, fileSize: Int)
        case timerHit
        case maxFileSizeHit

        var isRecording: Bool {
            switch self {
            case .recording: true
            default: false
            }
        }
    }

    private(set) var state: State {
        get {
            stateLock.withLock { $0 }
        }
        nonmutating set {
            stateLock.withLock { $0 = newValue }
            continuation?.yield(newValue)
        }
    }

    @Dependency(\.date) var date

    private let stateLock = OSAllocatedUnfairLock<State>(initialState: .idle)
    private var continuation: AsyncStream<State>.Continuation?

    private struct InvalidState: Swift.Error {}

    // TODO: ProTUN(pcap):  Add file storage capacity checks?
    mutating func start(
        with eventStream: AsyncStream<Event>,
        performing action: (URL, Int) -> Void,
        stateStream: (AsyncStream<State>) -> Void
    ) throws -> URL {
        guard state.canStart else {
            assertionFailure("Attempted to start PCAP session with invalid state")
            throw InvalidState()
        }
        @Dependency(\.pcapFileManager) var pcapFileManager
        try pcapFileManager.cleanUpAllPcapFiles()

        let startDate = date.now

        let fileURL = try pcapFileManager.newFileURL(startDate: startDate)
        let (combinedStream, continuation) = makeStream(from: eventStream)

        self.continuation = continuation

        stateStream(combinedStream)
        action(fileURL, DomainConstants.LogFiles.pcapMaxFileSize)

        state = .recording(.init(startDate: startDate, url: fileURL))

        return fileURL
    }

    mutating func stop() -> (URL, TimeInterval, Int)? {
        guard case let .recording(fileHandle) = state else {
            return nil
        }
        let interval = date.now.timeIntervalSince(fileHandle.startDate)
        @Dependency(\.fileManagerClient) var fileManagerClient
        do {
            let fileSize = try fileManagerClient.fileSize(at: fileHandle.url)
            state = .finished(duration: interval, fileSize: fileSize)
            return (fileHandle.url, interval, fileSize)
        } catch {
            // We were in the recording state, but nothing was recorded,
            // most likely because the connection never started
            state = .idle
            return nil
        }
    }
}

private extension PacketCaptureSession {
    private enum StreamAction {
        case state(State)
        case tick
        case event(Event)
    }

    func makeStream(from eventStream: AsyncStream<Event>) -> (AsyncStream<State>, AsyncStream<State>.Continuation) {
        @Dependency(\.continuousClock) var clock

        let (stateStream, stateContinuation) = AsyncStream<State>.makeStream()

        let timerSequence = clock.timer(interval: Self.timerInterval, tolerance: Self.timerTolerance)

        let mergedStream = merge(
            stateStream.map(StreamAction.state),
            timerSequence.map { _ in StreamAction.tick },
            eventStream.map(StreamAction.event)
        )
        .reductions(
            into: (state: State.idle, elapsedMinutes: 0, event: Event.packetCaptureStopped(reason: .alreadyStopped))
        ) { accumulator, action in
            switch action {
            case let .state(state):
                accumulator.state = state
            case .tick:
                accumulator.elapsedMinutes += 1
            case let .event(event):
                accumulator.event = event
            }
        }
        .map { state, elapsedMinutes, event in
            if case .packetCaptureStopped(reason: .maxSizeReached) = event {
                return State.maxFileSizeHit
            }
            return elapsedMinutes >= DomainConstants.LogFiles.pcapMaxDurationInMinutes ? State.timerHit : state
        }
        .removeDuplicates()
        .eraseToStream()

        return (mergedStream, stateContinuation)
    }
}

extension PacketCaptureSession.State {
    var canStart: Bool {
        switch self {
        case .recording:
            false
        case .idle, .finished, .timerHit, .maxFileSizeHit:
            true
        }
    }
}

extension PacketCaptureSession.State: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle:
            "idle"
        case .recording:
            "recording"
        case .finished:
            "finished"
        case .timerHit:
            "timerHit"
        case .maxFileSizeHit:
            "maxFileSizeHit"
        }
    }
}
