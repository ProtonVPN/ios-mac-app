//
//  InterfaceObserver.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 6/14/17.
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
#if os(iOS)
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
#else
import CoreWLAN
#endif
import SwiftyBeaver

private let log = SwiftyBeaver.self

/// Observes changes in the current Wi-Fi network.
public class InterfaceObserver: NSObject {

    /// A change in Wi-Fi state occurred.
    public static let didDetectWifiChange = Notification.Name("InterfaceObserverDidDetectWifiChange")

    private var queue: DispatchQueue?
    
    private var timer: DispatchSourceTimer?
    
    private var lastWifiName: String?

    /**
     Starts observing Wi-Fi updates.

     - Parameter queue: The `DispatchQueue` to deliver notifications to.
     **/
    public func start(queue: DispatchQueue) {
        self.queue = queue

        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(2))
        timer.setEventHandler {
            self.fireWifiChangeObserver()
        }
        timer.resume()

        self.timer = timer
    }

    /**
     Stops observing Wi-Fi updates.
     **/
    public func stop() {
        timer?.cancel()
        timer = nil
        queue = nil
    }

    private func fireWifiChangeObserver() {
        InterfaceObserver.fetchCurrentSSID {
            self.fireWifiChange(withSSID: $0)
        }
    }
    
    private func fireWifiChange(withSSID ssid: String?) {
        if ssid != lastWifiName {
            if let current = ssid {
                log.debug("SSID is now '\(current.maskedDescription)'")
                if let last = lastWifiName, (current != last) {
                    queue?.async {
                        NotificationCenter.default.post(name: InterfaceObserver.didDetectWifiChange, object: nil)
                    }
                }
            } else {
                log.debug("SSID is null")
            }
        }
        lastWifiName = ssid
    }

    /**
     Returns the current Wi-Fi SSID if any.

     - Returns: The current Wi-Fi SSID if any.
     **/
    public static func fetchCurrentSSID(completionHandler: @escaping (String?) -> Void) {
        #if os(iOS)
//        if #available(iOS 14.0, *) {
//            NEHotspotNetwork.fetchCurrent {
//                completionHandler($0?.ssid)
//            }
//        } else {
            guard let interfaceNames = CNCopySupportedInterfaces() as? [CFString] else {
                completionHandler(nil)
                return
            }
            for name in interfaceNames {
                guard let iface = CNCopyCurrentNetworkInfo(name) as? [String: Any] else {
                    continue
                }
                if let ssid = iface["SSID"] as? String {
                    completionHandler(ssid)
                    return
                }
            }
            completionHandler(nil)
//        }
        #else
        let client = CWWiFiClient.shared()
        let ssid = client.interfaces()?.compactMap { $0.ssid() }.first
        completionHandler(ssid)
        #endif
    }
}
