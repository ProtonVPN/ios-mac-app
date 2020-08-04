//
//  NETunnelInterface.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 8/27/17.
//  Copyright (c) 2020 Davide De Rosa. All rights reserved.
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

/// `TunnelInterface` implementation via NetworkExtension.
public class NETunnelInterface: TunnelInterface {
    private static let ipV4: UInt8 = 4
    
    private static let ipV6: UInt8 = 6
    
    private static let protocolNumbers: [UInt8: NSNumber] = [
        ipV4: NSNumber(value: AF_INET),
        ipV6: NSNumber(value: AF_INET6)
    ]

    private static let fallbackProtocolNumber = protocolNumbers[ipV4]!

    private weak var impl: NEPacketTunnelFlow?
    
    /// :nodoc:
    public init(impl: NEPacketTunnelFlow) {
        self.impl = impl
    }
    
    // MARK: TunnelInterface
    
    /// :nodoc:
    public var isPersistent: Bool {
        return false
    }
    
    // MARK: IOInterface
    
    /// :nodoc:
    public func setReadHandler(queue: DispatchQueue, _ handler: @escaping ([Data]?, Error?) -> Void) {
        loopReadPackets(queue, handler)
    }
    
    private func loopReadPackets(_ queue: DispatchQueue, _ handler: @escaping ([Data]?, Error?) -> Void) {

        // WARNING: runs in NEPacketTunnelFlow queue
        impl?.readPackets { [weak self] (packets, protocols) in
            queue.sync {
                self?.loopReadPackets(queue, handler)
                handler(packets, nil)
            }
        }
    }
    
    /// :nodoc:
    public func writePacket(_ packet: Data, completionHandler: ((Error?) -> Void)?) {
        let protocolNumber = NETunnelInterface.ipProtocolNumber(inPacket: packet)
        impl?.writePackets([packet], withProtocols: [protocolNumber])
        completionHandler?(nil)
    }
    
    /// :nodoc:
    public func writePackets(_ packets: [Data], completionHandler: ((Error?) -> Void)?) {
        let protocols = packets.map {
            NETunnelInterface.ipProtocolNumber(inPacket: $0)
        }
        impl?.writePackets(packets, withProtocols: protocols)
        completionHandler?(nil)
    }

    private static func ipProtocolNumber(inPacket packet: Data) -> NSNumber {
        guard !packet.isEmpty else {
            return fallbackProtocolNumber
        }

        // 'packet' contains the decrypted incoming IP packet data

        // The first 4 bits identify the IP version
        let ipVersion = (packet[0] & 0xf0) >> 4
        guard let protocolNumber = protocolNumbers[ipVersion] else {
            log.warning("Unrecognized IP version (\(ipVersion))")
            return fallbackProtocolNumber
        }
        return protocolNumber
    }
}
