//
//  Created on 03/10/2025 by Adam Viaud.
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
