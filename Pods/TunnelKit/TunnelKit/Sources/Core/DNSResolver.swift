//
//  DNSResolver.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 12/15/17.
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

/// Result of `DNSResolver`.
public struct DNSRecord {

    /// Address string.
    public let address: String

    /// `true` if IPv6.
    public let isIPv6: Bool
}

/// Convenient methods for DNS resolution.
public class DNSResolver {
    private static let queue = DispatchQueue(label: "DNSResolver")

    /**
     Resolves a hostname asynchronously.
     
     - Parameter hostname: The hostname to resolve.
     - Parameter timeout: The timeout in milliseconds.
     - Parameter queue: The queue to execute the `completionHandler` in.
     - Parameter completionHandler: The completion handler with the resolved addresses and an optional error.
     */
    public static func resolve(_ hostname: String, timeout: Int, queue: DispatchQueue, completionHandler: @escaping ([DNSRecord]?, Error?) -> Void) {
        var pendingHandler: (([DNSRecord]?, Error?) -> Void)? = completionHandler
        let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
        DNSResolver.queue.async {
            CFHostStartInfoResolution(host, .addresses, nil)
            guard let handler = pendingHandler else {
                return
            }
            DNSResolver.didResolve(host: host) { (records, error) in
                queue.async {
                    handler(records, error)
                    pendingHandler = nil
                }
            }
        }
        queue.asyncAfter(deadline: .now() + .milliseconds(timeout)) {
            guard let handler = pendingHandler else {
                return
            }
            CFHostCancelInfoResolution(host, .addresses)
            handler(nil, nil)
            pendingHandler = nil
        }
    }
    
    private static func didResolve(host: CFHost, completionHandler: @escaping ([DNSRecord]?, Error?) -> Void) {
        var success: DarwinBoolean = false
        guard let rawAddresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as Array? else {
            completionHandler(nil, nil)
            return
        }
        
        var records: [DNSRecord] = []
        for case let rawAddress as Data in rawAddresses {
            var ipAddress = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result: Int32 = rawAddress.withUnsafeBytes {
                let addr = $0.bindMemory(to: sockaddr.self).baseAddress!
                return getnameinfo(
                    addr,
                    socklen_t(rawAddress.count),
                    &ipAddress,
                    socklen_t(ipAddress.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
            }
            guard result == 0 else {
                continue
            }
            let address = String(cString: ipAddress)
            if rawAddress.count == 16 {
                records.append(DNSRecord(address: address, isIPv6: false))
            } else {
                records.append(DNSRecord(address: address, isIPv6: true))
            }
        }
        completionHandler(records, nil)
    }

    /**
     Returns a `String` representation from a numeric IPv4 address.
     
     - Parameter ipv4: The IPv4 address as a 32-bit number.
     - Returns: The string representation of `ipv4`.
     */
    public static func string(fromIPv4 ipv4: UInt32) -> String {
        var remainder = ipv4
        var groups: [UInt32] = []
        var base: UInt32 = 1 << 24
        while base > 0 {
            groups.append(remainder / base)
            remainder %= base
            base >>= 8
        }
        return groups.map { "\($0)" }.joined(separator: ".")
    }
    
    /**
     Returns a numeric representation from an IPv4 address.
     
     - Parameter string: The IPv4 address as a string.
     - Returns: The numeric representation of `string`.
     */
    public static func ipv4(fromString string: String) -> UInt32? {
        var addr = in_addr()
        let result = string.withCString {
            inet_pton(AF_INET, $0, &addr)
        }
        guard result > 0 else {
            return nil
        }
        return CFSwapInt32BigToHost(addr.s_addr)
    }

    private init() {
    }
}
