//
//  Created on 30/04/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  vpn-core-apple is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpn-core-apple is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpn-core-apple.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Dispatch
import Ergonomics
import Network

struct NetworkPath: Equatable {
    private(set) var status: NWPath.Status
}

extension NetworkPath {
    init(rawValue: NWPath) {
        self.status = rawValue.status
    }
}

struct NetworkPathMonitor {
    var subscribe: @Sendable () -> AsyncStream<NetworkPath>
    var start: @Sendable () -> Void
    var stop: @Sendable () -> Void
}

extension NetworkPathMonitor: Sendable {}

extension NetworkPathMonitor: DependencyKey {
    static let liveValue: NetworkPathMonitor = {
        let queue = DispatchQueue(label: "ch.proton.nwpath.monitor")
        let networkMonitor = NWPathMonitor(prohibitedInterfaceTypes: [.other])

        let (stream, continuation) = AsyncStream<NetworkPath>.makeStream()

        let streamSource: StreamSource<NetworkPath>
        if #available(macOS 15, iOS 18.0, tvOS 18.0, *) {
            let shared = stream.removeDuplicates().share()
            streamSource = .asyncAlgorithms { shared.eraseToStream() }
        } else {
            streamSource = .sharedStream(stream.removeDuplicates().sharedStream)
        }

        nonisolated(unsafe) var started = false

        return .init {
            streamSource.newStream
        } start: {
            queue.sync {
                guard !started else {
                    return
                }

                networkMonitor.pathUpdateHandler = { path in
                    continuation.yield(.init(rawValue: path))
                }
                networkMonitor.start(queue: queue)
                started = true
            }
        } stop: {
            queue.sync {
                guard started else {
                    return
                }

                networkMonitor.cancel()
                started = false
            }
        }
    }()

    static let testValue: NetworkPathMonitor = {
        let (stream, continuation) = AsyncStream<NetworkPath>.makeStream()

        return .init {
            stream
        } start: {
            continuation.yield(.init(status: .satisfied))
        } stop: {
            ()
        }
    }()
}

extension DependencyValues {
    var pathMonitor: NetworkPathMonitor {
        get { self[NetworkPathMonitor.self] }
        set { self[NetworkPathMonitor.self] = newValue }
    }
}

extension NetworkPath: CustomStringConvertible {
    var description: String {
        switch status {
        case .satisfied:
            return "satisfied"
        case .unsatisfied:
            return "unsatisfied"
        case .requiresConnection:
            return "requiredConnection"
        @unknown default:
            return "unknown"
        }
    }
}
