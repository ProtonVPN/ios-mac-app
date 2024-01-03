//
//  Created on 09.08.23.
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
import Network

import Dependencies

import Domain
import VPNAppCore

/// Misconfigured Local Networks
///
/// Networks come in all shapes and sizes. All local networks *should* comply with RFC1918 for distributing local IP
/// addresses, but not all of them do. In cases where they don't, the OS can decide that, since the IP "looks" like a
/// local IP according to the interface, it should send the traffic over the local network unencrypted. This is
/// obviously bad, so we scan the interfaces of the device to see if any aren't compliant with RFC1918 (which defines
/// which IPs are "LAN" IPs) or RFC3927 (which defines "peer-to-peer" IPs). If they aren't, display a warning to the
/// user encouraging them to use Kill Switch, which will route *all* traffic over the VPN, regardless of whether it looks
/// like it's destined for the local network according to the interface configuration.
struct MisconfiguredLocalNetworkIntercept: VpnConnectionInterceptPolicyItem {
    typealias Factory = CoreAlertServiceFactory &
        NetworkInterfacePropertiesProviderFactory &
        PropertiesManagerFactory

    let alertService: CoreAlertService
    let propertiesManager: PropertiesManagerProtocol
    let interfacePropertiesProvider: NetworkInterfacePropertiesProvider

    init(
        alertService: CoreAlertService,
        propertiesManager: PropertiesManagerProtocol,
        interfacePropertiesProvider: NetworkInterfacePropertiesProvider
    ) {
        self.alertService = alertService
        self.propertiesManager = propertiesManager
        self.interfacePropertiesProvider = interfacePropertiesProvider
    }

    init(factory: Factory) {
        self.init(
            alertService: factory.makeCoreAlertService(),
            propertiesManager: factory.makePropertiesManager(),
            interfacePropertiesProvider: factory.makeInterfacePropertiesProvider()
        )
    }

    public func shouldIntercept(
        _ connectionProtocol: ConnectionProtocol,
        isKillSwitchOn: Bool,
        completion: @escaping (VpnConnectionInterceptResult) -> Void
    ) {
        guard propertiesManager.featureFlags.unsafeLanWarnings else {
            completion(.allow)
            return
        }

        guard !isKillSwitchOn else {
            completion(.allow) // kill switch mitigates this issue by using the tunnel for everything
            return
        }

        var badInterface: NetworkInterface?
        do {
            badInterface = try interfacePropertiesProvider
                .withNetworkInterfaceInfo { $0.first(where: \.hasBadRanges) }
        } catch {
            log.error("Couldn't fetch interface information: \(error)")
        }

        guard let badInterface else {
            completion(.allow)
            return
        }

        alertService.push(alert: ConnectingWithBadLANAlert(
            badIpAndPrefix: badInterface.ipv4SubnetDescription,
            badInterfaceName: badInterface.name,
            killSwitchOnHandler: {
                completion(.intercept(.init(
                    newProtocol: connectionProtocol,
                    smartProtocolWithoutWireGuard: false,
                    newKillSwitch: true
                )))
            },
            connectAnywayHandler: {
                completion(.allow)
            }
        ))
    }
}

extension NetworkInterface {
    static let localIpv4Ranges: [Range<IPv4Address>] = [
        IPv4Address("10.0.0.0")!..<IPv4Address("10.255.255.255")!, // RFC1918
        IPv4Address("172.16.0.0")!..<IPv4Address("172.31.255.255")!,
        IPv4Address("192.168.0.0")!..<IPv4Address("192.168.255.255")!,
        IPv4Address("169.254.0.0")!..<IPv4Address("169.254.255.255")!, // RFC3927
    ]

    var hasBadRanges: Bool {
        guard let ipv4 = addr as? IPv4Address else { return false }

        // We don't care about the interface if it isn't being used.
        guard flags.contains([.up, .running]) else { return false }

        // We don't care about point-to-point or loopback interfaces, we care about how we're reaching the WAN.
        guard flags.isDisjoint(with: [.pointToPoint, .loopback]) else { return false }

        guard let maskIpv4 = mask as? IPv4Address else { return false }

        let range = Range<IPv4Address>(ip: ipv4, netmask: maskIpv4)
        return !Self.localIpv4Ranges.contains { $0.isSuperSet(of: range) }
    }

    var ipv4SubnetDescription: String? {
        guard let addr = addr as? IPv4Address else { return nil }

        var result = String(describing: addr)
        if let mask = mask as? IPv4Address {
            result += "/\(mask.leadingOnesInMask)"
        }

        return result
    }
}

fileprivate extension Range {
    func isSuperSet(of other: Range<Bound>) -> Bool {
        self.lowerBound <= other.lowerBound &&
        other.upperBound <= self.upperBound
    }
}

extension IPv4Address: Comparable {
    public static func < (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
        lhs.rawValue.withUnsafeBytes { lhsBytes in
            rhs.rawValue.withUnsafeBytes { rhsBytes in
                memcmp(lhsBytes.baseAddress, rhsBytes.baseAddress, 4) < 0
            }
        }
    }
}

extension IPv4Address {
    var leadingOnesInMask: Int {
        var result = 0
        for byte in rawValue {
            guard byte != UInt8.max else {
                result += UInt8.bitWidth
                continue
            }

            result += (~byte).leadingZeroBitCount
            break
        }

        return result
    }
}

extension IPv6Address: Comparable {
    public static func < (lhs: IPv6Address, rhs: IPv6Address) -> Bool {
        lhs.rawValue.withUnsafeBytes { lhsBytes in
            rhs.rawValue.withUnsafeBytes { rhsBytes in
                memcmp(lhsBytes.baseAddress, rhsBytes.baseAddress, 16) < 0
            }
        }
    }
}

extension Range<IPv4Address> {
    init(ip: IPv4Address, netmask: IPv4Address) {
        self = ip.rawValue.withUnsafeBytes { ipBytes in
            netmask.rawValue.withUnsafeBytes { netmaskBytes in
                let ipValue = ipBytes.assumingMemoryBound(to: UInt32.self).baseAddress?.pointee ?? 0
                let netmaskValue = netmaskBytes.assumingMemoryBound(to: UInt32.self).baseAddress?.pointee ?? 0

                var low = ipValue & netmaskValue
                var hi = low | ~netmaskValue

                let lowData = Data(bytes: &low, count: MemoryLayout<UInt32>.size)
                let hiData = Data(bytes: &hi, count: MemoryLayout<UInt32>.size)

                return IPv4Address(lowData)!..<IPv4Address(hiData)!
            }
        }
    }
}
