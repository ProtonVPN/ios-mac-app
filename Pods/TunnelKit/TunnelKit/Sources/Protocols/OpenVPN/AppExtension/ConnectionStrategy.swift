//
//  ConnectionStrategy.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 6/18/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

class ConnectionStrategy {
    struct Endpoint: CustomStringConvertible {
        let record: DNSRecord
        
        let proto: EndpointProtocol
        
        var isValid: Bool {
            if record.isIPv6 {
                return proto.socketType != .udp4 && proto.socketType != .tcp4
            } else {
                return proto.socketType != .udp6 && proto.socketType != .tcp6
            }
        }
        
        // MARK: CustomStringConvertible

        var description: String {
            return "\(record.address.maskedDescription):\(proto)"
        }
    }

    private let hostname: String?

    private let endpointProtocols: [EndpointProtocol]
    
    private var endpoints: [Endpoint]

    private var currentEndpointIndex: Int
    
    private let resolvedAddresses: [String]

    init(configuration: OpenVPNTunnelProvider.Configuration) {
        hostname = configuration.sessionConfiguration.hostname
        guard var endpointProtocols = configuration.sessionConfiguration.endpointProtocols else {
            fatalError("No endpoints provided")
        }
        if configuration.sessionConfiguration.randomizeEndpoint ?? false {
            endpointProtocols.shuffle()
        }
        self.endpointProtocols = endpointProtocols

        currentEndpointIndex = 0
        if let resolvedAddresses = configuration.resolvedAddresses {
            if configuration.prefersResolvedAddresses {
                log.debug("Will use pre-resolved addresses only")
                endpoints = ConnectionStrategy.unrolledEndpoints(
                    records: resolvedAddresses.map { DNSRecord(address: $0, isIPv6: false) },
                    protos: endpointProtocols
                )
            } else {
                log.debug("Will use DNS resolution with fallback to pre-resolved addresses")
                endpoints = []
            }
            self.resolvedAddresses = resolvedAddresses
        } else {
            log.debug("Will use DNS resolution")
            guard hostname != nil else {
                fatalError("Either configuration.sessionConfiguration.hostname or configuration.resolvedAddresses required")
            }
            endpoints = []
            resolvedAddresses = []
        }
    }
    
    private static func unrolledEndpoints(ipv4Addresses: [String], protos: [EndpointProtocol]) -> [Endpoint] {
        return unrolledEndpoints(records: ipv4Addresses.map { DNSRecord(address: $0, isIPv6: false) }, protos: protos)
    }

    private static func unrolledEndpoints(records: [DNSRecord], protos: [EndpointProtocol]) -> [Endpoint] {
        guard !records.isEmpty else {
            return []
        }
        var endpoints: [Endpoint] = []
        for r in records {
            for p in protos {
                let endpoint = Endpoint(record: r, proto: p)
                guard endpoint.isValid else {
                    continue
                }
                endpoints.append(endpoint)
            }
        }
        log.debug("Unrolled endpoints: \(endpoints.maskedDescription)")
        return endpoints
    }
    
    func hasEndpoint() -> Bool {
        return currentEndpointIndex < endpoints.count
    }

    func currentEndpoint() -> Endpoint {
        guard hasEndpoint() else {
            fatalError("Endpoint index out of bounds (\(currentEndpointIndex) >= \(endpoints.count))")
        }
        return endpoints[currentEndpointIndex]
    }

    @discardableResult
    func tryNextEndpoint() -> Bool {
        guard hasEndpoint() else {
            return false
        }
        currentEndpointIndex += 1
        guard currentEndpointIndex < endpoints.count else {
            log.debug("Exhausted endpoints")
            return false
        }
        log.debug("Try next endpoint: \(currentEndpoint().maskedDescription)")
        return true
    }
    
    func createSocket(
        from provider: NEProvider,
        timeout: Int,
        queue: DispatchQueue,
        completionHandler: @escaping (GenericSocket?, Error?) -> Void) {

        if hasEndpoint() {
            let endpoint = currentEndpoint()
            log.debug("Pick current endpoint: \(endpoint.maskedDescription)")
            let socket = provider.createSocket(to: endpoint)
            completionHandler(socket, nil)
            return
        }
        log.debug("No endpoints available, will resort to DNS resolution")

        guard let hostname = hostname else {
            log.error("DNS resolution unavailable: no hostname provided!")
            completionHandler(nil, OpenVPNTunnelProvider.ProviderError.dnsFailure)
            return
        }
        log.debug("DNS resolve hostname: \(hostname.maskedDescription)")
        DNSResolver.resolve(hostname, timeout: timeout, queue: queue) { (records, error) in
            self.currentEndpointIndex = 0
            if let records = records, !records.isEmpty {
                log.debug("DNS resolved addresses: \(records.map { $0.address }.maskedDescription)")
                self.endpoints = ConnectionStrategy.unrolledEndpoints(records: records, protos: self.endpointProtocols)
            } else {
                log.error("DNS resolution failed!")
                log.debug("Fall back to resolved addresses: \(self.resolvedAddresses.maskedDescription)")
                self.endpoints = ConnectionStrategy.unrolledEndpoints(ipv4Addresses: self.resolvedAddresses, protos: self.endpointProtocols)
            }
            
            guard self.hasEndpoint() else {
                log.error("No endpoints available")
                completionHandler(nil, OpenVPNTunnelProvider.ProviderError.dnsFailure)
                return
            }

            let targetEndpoint = self.currentEndpoint()
            log.debug("Pick current endpoint: \(targetEndpoint.maskedDescription)")
            let socket = provider.createSocket(to: targetEndpoint)
            completionHandler(socket, nil)
        }
    }
}

private extension NEProvider {
    func createSocket(to endpoint: ConnectionStrategy.Endpoint) -> GenericSocket {
        let ep = NWHostEndpoint(hostname: endpoint.record.address, port: "\(endpoint.proto.port)")
        switch endpoint.proto.socketType {
        case .udp, .udp4, .udp6:
            let impl = createUDPSession(to: ep, from: nil)
            return NEUDPSocket(impl: impl)
            
        case .tcp, .tcp4, .tcp6:
            let impl = createTCPConnection(to: ep, enableTLS: false, tlsParameters: nil, delegate: nil)
            return NETCPSocket(impl: impl)
        }
    }
}
