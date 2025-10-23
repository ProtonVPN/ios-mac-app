//
//  Created on 30/09/2025 by Adam Viaud.
//
//  Copyright (c) 2025 Proton AG
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

import NetworkExtension

extension NENetworkRule {
    static var dnsRule: NENetworkRule {
        get throws {
            if #available(macOS 15, *) {
                return .init(
                    remoteNetworkEndpoint: NWEndpoint.hostPort(host: "10.2.0.1", port: .any),
                    remotePrefix: 32,
                    localNetworkEndpoint: nil,
                    localPrefix: 0,
                    protocol: .any,
                    direction: .outbound
                )
            } else {
                let selectorName = "initWithDestinationHost:protocol:"
                let sel = NSSelectorFromString(selectorName)

                guard responds(to: sel) else {
                    throw NSError(domain: "ProtonVPNPlutonium.DNSNetworkRuleError", code: 1)
                }

                let endpoint = NWEndpoint.hostPort(host: .init("10.2.0.1"), port: .any)
                let nwProtocolValue: NSInteger = 0 // NENetworkRuleProtocolAny

                guard let value = perform(sel, with: endpoint, with: nwProtocolValue)?.takeUnretainedValue() as? NENetworkRule else {
                    throw NSError(domain: "ProtonVPNPlutonium.DNSNetworkRuleError", code: 1)
                }

                return value
            }
        }
    }
}

extension NWEndpoint {
    var isDNSRequest: Bool {
        switch self {
        case .hostPort(_, 53):
            true
        default:
            false
        }
    }
}

extension NEAppProxyTCPFlow {
    /// Returns the correct remote endpoint for both < macOS 15 and ≥ macOS 15.
    var remoteEndpoint: NWEndpoint? {
        if #available(macOS 15, *) {
            self.remoteFlowEndpoint
        } else {
            value(forKey: "remoteEndpoint") as? NWEndpoint
        }
    }
}

extension NEAppProxyUDPFlow {
    /// Returns the correct local endpoint for both < macOS 15 and ≥ macOS 15.
    var localEndpoint: NWEndpoint? {
        if #available(macOS 15, *) {
            self.localFlowEndpoint
        } else {
            value(forKey: "localEndpoint") as? NWEndpoint
        }
    }
}

extension NWEndpoint {
    var ipv4String: String? {
        guard
            case let .hostPort(host, _) = self,
            case let .ipv4(addr) = host
        else { return nil }

        return addr.asString
    }
}

extension IPv4Address {
    var asString: String? {
        var addr = rawValue.withUnsafeBytes { $0.load(as: in_addr.self) }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return String(cString: &buffer)
    }
}

// we're taking responsibility for thread safety
extension NEAppProxyFlow: @unchecked @retroactive Sendable {}
