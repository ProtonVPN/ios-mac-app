//
//  Created on 02/06/2025 by Shahin Katebi.
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

import Foundation
import NetworkExtension

/*
 * NetworkExtension API Compatibility Extensions
 *
 * Apple completely removed old NEAppProxyFlow APIs in macOS 15 SDK:
 * • NEAppProxyTCPFlow.remoteEndpoint → remoteFlowEndpoint
 * • NEAppProxyFlow.open(withLocalEndpoint:) → open(withLocalFlowEndpoint:)
 *
 * Since the old APIs were completely removed (not just deprecated), Swift packages
 * compiled against macOS 15 SDK cannot see them at all, making standard #available
 * checks impossible. These extensions use runtime techniques to access old APIs
 * on older macOS while using new APIs on macOS 15+.
 */

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

extension NEAppProxyUDPFlow {
    /// Reads datagrams using the appropriate API for the macOS version:
    /// On macOS 15+:     `readDatagrams()`
    /// On older macOS:   `readDatagrams(completionHandler:)`
    func readDatagramsUniversal(completionHandler: @escaping ([(Data, NWEndpoint)]?, Error?) -> Void) {
        if #available(macOS 15, *) {
            self.readDatagrams(completionHandler: completionHandler)
        } else {
            let selectorName = "readDatagramsWithCompletionHandler:"
            let sel = NSSelectorFromString(selectorName)

            guard
                responds(to: sel),
                let methodIMP = method(for: sel)
            else {
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: "'\(selectorName)' method not found on NEAppProxyUDPFlow.",
                ]
                let err = NSError(
                    domain: "ProtonVPNPlutonium.UniversalReadDatagramsError",
                    code: 1,
                    userInfo: userInfo
                )
                completionHandler(nil, err)
                return
            }

            // Cast the IMP to a Swift-callable C‐function pointer:
            //
            //   ObjC signature is:
            //     - (void)readDatagramsWithCompletionHandler:(void (^)(NSArray* _Nullable, NSError * _Nullable))handler;
            //
            typealias ReadDatagramsFn = @convention(c) (
                AnyObject, // "self" pointer
                Selector, // the selector
                @escaping (NSArray?, NSError?) -> Void // the completion block
            ) -> Void

            let fn = unsafeBitCast(methodIMP, to: ReadDatagramsFn.self)

            // Call the old Objective-C method with a wrapper
            fn(self, sel) { array, error in
                if let error {
                    completionHandler(nil, error)
                    return
                }

                // Convert NSArray to [(Data, NWEndpoint)]
                var datagrams: [(Data, NWEndpoint)] = []
                if let array {
                    for item in array {
                        // Extract data and endpoint from each datagram object
                        if let datagramData = (item as AnyObject).value(forKey: "data") as? Data,
                           let endpoint = (item as AnyObject).value(forKey: "remoteEndpoint") as? NWEndpoint {
                            datagrams.append((datagramData, endpoint))
                        }
                    }
                }

                completionHandler(datagrams.isEmpty ? nil : datagrams, nil)
            }
        }
    }

    /// Writes datagrams using the appropriate API for the macOS version:
    /// On macOS 15+:     `writeDatagrams(_:)`
    /// On older macOS:   `writeDatagrams(_:sentBy:completionHandler:)`
    func writeDatagramsUniversal(
        _ datagrams: [(Data, NWEndpoint)],
        completionHandler: @escaping (Error?) -> Void
    ) {
        if #available(macOS 15, *) {
            self.writeDatagrams(datagrams, completionHandler: completionHandler)
        } else {
            let selectorName = "writeDatagrams:sentBy:completionHandler:"
            let sel = NSSelectorFromString(selectorName)

            guard
                responds(to: sel),
                let methodIMP = method(for: sel)
            else {
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: "'\(selectorName)' method not found on NEAppProxyUDPFlow.",
                ]
                let err = NSError(
                    domain: "ProtonVPNPlutonium.UniversalWriteError",
                    code: 1,
                    userInfo: userInfo
                )
                completionHandler(err)
                return
            }

            // Convert [(Data, NWEndpoint)] to NSArray of datagram objects
            let datagramsArray = NSMutableArray()
            for (data, endpoint) in datagrams {
                // Create a simple dictionary to represent the datagram
                let datagramDict: [String: Any] = [
                    "data": data,
                    "remoteEndpoint": endpoint,
                ]
                datagramsArray.add(datagramDict)
            }

            // Cast the IMP to a Swift-callable C‐function pointer:
            //
            //   ObjC signature is:
            //     - (void)writeDatagrams:(NSArray*)datagrams
            //                     sentBy:(NWEndpoint*)remoteEndpoint
            //              completionHandler:(void (^)(NSError * _Nullable))handler;
            //
            typealias WriteDatagramsFn = @convention(c) (
                AnyObject, // "self" pointer
                Selector, // the selector
                NSArray, // the datagrams array
                AnyObject?, // the sentBy endpoint (can be nil)
                @escaping (NSError?) -> Void // the completion block
            ) -> Void

            let fn = unsafeBitCast(methodIMP, to: WriteDatagramsFn.self)

            // Call the old Objective-C method with nil sentBy
            fn(self, sel, datagramsArray, nil, completionHandler)
        }
    }
}

extension NEAppProxyFlow {
    /// Opens the flow, using:
    /// On macOS 15+:     `open(withLocalFlowEndpoint:completionHandler:)`
    /// On older macOS:   dynamical call to `open(withLocalEndpoint:completionHandler:)`
    func open(
        withLocalEndpoint endpoint: NWEndpoint?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        if #available(macOS 15, *) {
            self.open(withLocalFlowEndpoint: endpoint, completionHandler: completionHandler)
        } else {
            let selectorName = "openWithLocalEndpoint:completionHandler:"
            let sel = NSSelectorFromString(selectorName)

            guard
                responds(to: sel),
                let methodIMP = method(for: sel)
            else {
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: "‘\(selectorName)’ method not found on NEAppProxyFlow.",
                ]
                let err = NSError(
                    domain: "ProtonVPNPlutonium.FlowOpenError",
                    code: 1,
                    userInfo: userInfo
                )
                completionHandler(err)
                return
            }

            // Cast the IMP to a Swift-callable C‐function pointer:
            //
            //   ObjC signature is:
            //     - (void)openWithLocalEndpoint:(NWHostEndpoint*)endpoint
            //                     completionHandler:(void (^)(NSError * _Nullable))handler;
            //
            typealias OpenFn = @convention(c) (
                AnyObject, // "self" pointer
                Selector, // the selector
                AnyObject?, // the NWEndpoint? as AnyObject?
                @escaping (Error?) -> Void // the completion block
            ) -> Void

            let fn = unsafeBitCast(methodIMP, to: OpenFn.self)

            // Call the old Objective-C method
            fn(self, sel, endpoint as AnyObject?, completionHandler)
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
