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
                    domain: "CompatOpenError",
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
