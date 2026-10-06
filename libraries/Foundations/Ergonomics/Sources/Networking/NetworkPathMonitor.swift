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
import DependenciesMacros
import Ergonomics
import Network

public struct NetworkPath: Equatable, Sendable {
    static let tunnelInterfacePrefixes = ["utun", "tun", "ipsec", "tun", "tap", "wg"]

    public private(set) var status: NWPath.Status
    private(set) var interfaceName: String?
    /// The system's index for the physical interface this path prefers, or nil when the path has none. A socket
    /// bound to this index can only leave the device through that interface.
    public private(set) var interfaceIndex: UInt32?
    public private(set) var interfaceType: NWInterface.InterfaceType?
    private(set) var gateways: [String]
    private(set) var supportsIPv4: Bool
    private(set) var supportsIPv6: Bool

    public init(
        status: NWPath.Status,
        interfaceName: String? = nil,
        interfaceIndex: UInt32? = nil,
        interfaceType: NWInterface.InterfaceType? = nil,
        gateways: [String],
        supportsIPv4: Bool,
        supportsIPv6: Bool
    ) {
        self.status = status
        self.interfaceName = interfaceName
        self.interfaceIndex = interfaceIndex
        self.interfaceType = interfaceType
        self.gateways = gateways
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
    }
}

public extension NetworkPath {
    static let initial: Self = .init(
        status: .unsatisfied,
        gateways: [],
        supportsIPv4: false,
        supportsIPv6: false
    )

    var isUsable: Bool {
        status == .satisfied || status == .requiresConnection
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
        self.interfaceIndex = physical.flatMap { UInt32(exactly: $0.index) }
        self.interfaceType = physical?.type
        self.gateways = path.gateways.map(\.debugDescription).sorted()
        self.supportsIPv4 = path.supportsIPv4
        self.supportsIPv6 = path.supportsIPv6
    }
}

@DependencyClient
public struct NetworkPathMonitor: Sendable {
    /// Opens a stream of paths. Repeats are already dropped, so every value describes a path that
    /// differs from the one before it. A new subscriber may first receive paths the system reported
    /// while nobody was subscribed.
    public var subscribe: @Sendable () -> AsyncStream<NetworkPath> = { .finished }

    /// The path the system reports right now. Any thread can call this, and it never suspends. A
    /// subscriber that just received a path gets that path or a newer one. Until the system reports
    /// its first path, this is an unsatisfied path with no interface.
    public var currentPath: @Sendable () -> NetworkPath = { .initial }
}

extension NetworkPathMonitor: DependencyKey {
    /// Monitoring begins when this client is first used and lasts until the process exits. The
    /// system does not let a cancelled monitor start again, so nothing here cancels it.
    public static let liveValue: NetworkPathMonitor = {
        let networkMonitor = NWPathMonitor(prohibitedInterfaceTypes: [.other])
        let paths = networkMonitor.map { NetworkPath($0) }.removeDuplicates()

        let streamSource: StreamSource<NetworkPath>
        if #available(macOS 15, iOS 18.0, tvOS 18.0, *) {
            let shared = paths.share()
            streamSource = .asyncAlgorithms { shared.eraseToStream() }
        } else {
            streamSource = .sharedStream(paths.sharedStream)
        }

        return .init {
            streamSource.newStream
        } currentPath: {
            NetworkPath(networkMonitor.currentPath)
        }
    }()

    public static let testValue = NetworkPathMonitor(subscribe: { .finished }, currentPath: { .initial })
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
