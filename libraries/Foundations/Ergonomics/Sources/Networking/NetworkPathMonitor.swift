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

public struct NetworkPath: Equatable, Sendable {
    static let tunnelInterfacePrefixes = ["utun", "tun", "ipsec", "tun", "tap", "wg"]

    public private(set) var status: NWPath.Status
    private(set) var interfaceName: String?
    public private(set) var interfaceType: NWInterface.InterfaceType?
    private(set) var gateways: [String]
    private(set) var supportsIPv4: Bool
    private(set) var supportsIPv6: Bool

    public var isUsable: Bool {
        status == .satisfied || status == .requiresConnection
    }

    public init(status: NWPath.Status, interfaceName: String? = nil, interfaceType: NWInterface.InterfaceType? = nil, gateways: [String], supportsIPv4: Bool, supportsIPv6: Bool) {
        self.status = status
        self.interfaceName = interfaceName
        self.interfaceType = interfaceType
        self.gateways = gateways
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
    }
}

public extension NetworkPath {
    init(_ path: NWPath) {
        self.status = path.status

        // The first physical interface - `availableInterfaces` on NWPath is already sorted in order of preference.
        let physical = path.availableInterfaces.first { interface in
            switch interface.type {
            case .wifi, .cellular, .wiredEthernet: true
            case .loopback: false
            case .other: Self.tunnelInterfacePrefixes.allSatisfy { !interface.name.hasPrefix($0) }
            @unknown default: false
            }
        }

        self.interfaceName = physical?.name
        self.interfaceType = physical?.type
        self.gateways = path.gateways.map(\.debugDescription).sorted()
        self.supportsIPv4 = path.supportsIPv4
        self.supportsIPv6 = path.supportsIPv6
    }
}

public struct NetworkPathMonitor: Sendable {
    public var subscribe: @Sendable () -> AsyncStream<NetworkPath>
    public var start: @Sendable () -> Void
    public var stop: @Sendable () -> Void
}

extension NetworkPathMonitor: DependencyKey {
    public static let liveValue: NetworkPathMonitor = {
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
                    continuation.yield(.init(path))
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

    public static let testValue: NetworkPathMonitor = {
        let (stream, continuation) = AsyncStream<NetworkPath>.makeStream()

        return .init {
            stream
        } start: {
            continuation.yield(.init(
                status: .satisfied,
                interfaceName: "en0",
                interfaceType: .wiredEthernet,
                gateways: ["192.168.1.1"],
                supportsIPv4: true,
                supportsIPv6: false
            ))
        } stop: {
            ()
        }
    }()
}

public extension DependencyValues {
    var pathMonitor: NetworkPathMonitor {
        get { self[NetworkPathMonitor.self] }
        set { self[NetworkPathMonitor.self] = newValue }
    }
}

extension NetworkPath: CustomStringConvertible {
    public var description: String {
        let status = switch status {
        case .satisfied: "satisfied"
        case .unsatisfied: "unsatisfied"
        case .requiresConnection: "requiresConnection"
        @unknown default: "unknown"
        }

        let interfaceType = switch interfaceType {
        case .cellular: "cellular"
        case .wifi: "wifi"
        case .wiredEthernet: "wiredEthernet"
        case .loopback: "loopback"
        case .other: "other"
        case nil: "nil"
        @unknown default: "unknown"
        }

        var supported: [String] = []
        if supportsIPv4 {
            supported.append("IPv4")
        }
        if supportsIPv6 {
            supported.append("IPv6")
        }

        let supports = "supports \(supported.joined(separator: ", "))"

        return "\(status) (\(optional: interfaceName) \(interfaceType)), \(supports)"
    }
}
