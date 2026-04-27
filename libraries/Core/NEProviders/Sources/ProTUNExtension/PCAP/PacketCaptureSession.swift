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

#if os(iOS) && DEBUG
    import AsyncAlgorithms
    import Clocks
    import Dependencies
    import Foundation
    import os

    struct PacketCaptureSession {
        static let pcapPathExtension: String = "pcap"
        private static let pcapMaxDurationInMinutes: Int = 20
        private static let pcapMaxFileSize: UInt64 = 5 * (1 << 20)
        private static let timerInterval: Duration = .minutes(1)
        private static let timerTolerance: Duration = .seconds(1)

        enum State: Equatable {
            case idle
            case recording(to: URL, since: Date)
            case finished(duration: TimeInterval, fileSize: Int64)
            case timerHit
            case maxFileSizeHit
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

        private let stateLock = OSAllocatedUnfairLock<State>(initialState: .idle)
        private var continuation: AsyncStream<State>.Continuation?

        private struct InvalidState: Swift.Error {}

        static func retrieveLastPcapFileURL() -> URL? {
            do {
                let fileManager = FileManager.default
                let containerURL = try fileManager.mainContainerURL
                let files = try fileManager.contentsOfDirectory(
                    at: containerURL,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                return files
                    .filter { $0.pathExtension == Self.pcapPathExtension }
                    .sortedByCreationDate
                    .first
            } catch {
                return nil
            }
        }

        @discardableResult
        static func cleanUpLastPcapFile() throws -> Bool {
            guard let lastPcapFileURL = retrieveLastPcapFileURL() else { return false }
            try FileManager.default.removeItem(at: lastPcapFileURL)
            return true
        }

        // TODO: Add file storage capacity checks?
        mutating func start(
            with eventStream: AsyncStream<Event>,
            performing action: (URL, UInt64) -> Void,
            stateStream: (AsyncStream<State>) -> Void
        ) throws -> URL {
            guard state.canStart else {
                throw InvalidState()
            }

            try Self.cleanUpLastPcapFile()

            let startDate: Date = .now

            let fileURL = try fileURL(for: startDate)
            let (combinedStream, continuation) = makeStream(from: eventStream)

            self.continuation = continuation

            stateStream(combinedStream)
            action(fileURL, Self.pcapMaxFileSize)

            state = .recording(to: fileURL, since: startDate)

            return fileURL
        }

        mutating func stop(performing action: (() -> Void)? = nil) throws -> (URL, TimeInterval, Int64) {
            guard case let .recording(fileURL, startDate) = state else {
                throw InvalidState()
            }
            let interval = Date.now.timeIntervalSince(startDate)
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path())
            let fileSize = (fileAttributes[.size] as? Int64) ?? .zero
            state = .finished(duration: interval, fileSize: fileSize)
            action?()
            return (fileURL, interval, fileSize)
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
                return elapsedMinutes >= Self.pcapMaxDurationInMinutes ? State.timerHit : state
            }
            .removeDuplicates()
            .eraseToStream()

            return (mergedStream, stateContinuation)
        }

        func fileURL(for startDate: Date) throws -> URL {
            let containerURL = try FileManager.default.mainContainerURL

            let formatter = DateFormatter()
            formatter.dateFormat = "ddMMyyyyHHmmss"
            formatter.locale = Locale(identifier: "en_US_POSIX")

            let timestamp = formatter.string(from: startDate)

            return containerURL
                .appendingPathComponent(timestamp)
                .appendingPathExtension(Self.pcapPathExtension)
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

    private extension Collection<URL> {
        var sortedByCreationDate: [URL] {
            sorted { a, b in
                let d1 = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let d2 = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return d1 > d2
            }
        }
    }
#endif
