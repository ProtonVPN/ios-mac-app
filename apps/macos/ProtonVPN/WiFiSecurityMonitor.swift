//
//  WiFiSecurityObtainer.swift
//  ProtonVPN - Created on 07.05.20.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import CoreWLAN
import Reachability
import vpncore

protocol WiFiSecurityMonitorFactory {
    func makeWiFiSecurityMonitor() -> WiFiSecurityMonitor
}

protocol WiFiSecurityMonitorDelegate: AnyObject {
    func unsecureWiFiDetected()
}

public final class WiFiSecurityMonitor: CWNetworkProfile {

    /*
     kCWSecurityNone                 = 0,
     kCWSecurityWEP                  = 1,
     kCWSecurityWPAPersonal          = 2,
     kCWSecurityWPAPersonalMixed     = 3,
     kCWSecurityWPA2Personal         = 4,
     kCWSecurityPersonal             = 5,
     kCWSecurityDynamicWEP           = 6,
     kCWSecurityWPAEnterprise        = 7,
     kCWSecurityWPAEnterpriseMixed   = 8,
     kCWSecurityWPA2Enterprise       = 9,
     kCWSecurityEnterprise           = 10,
     kCWSecurityUnknown              = NSIntegerMax
     */

    private let reachability = Reachability()
    private let wifiClient: CWWiFiClient = CWWiFiClient()

    public private(set) var wifiName: String?

    weak var delegate: WiFiSecurityMonitorDelegate?

    func startMonitoring() {
        guard let reachability = reachability else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        do {
            try reachability.startNotifier()
        } catch {
            PMLog.D("could not start reachability notifier")
        }
    }

    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        guard let interfaces = wifiClient.interfaces() else { return }

        switch reachability.connection {
        case .wifi:
            PMLog.D("Reachable via WiFi")
            // just check all available wifi connections and if at least one of them is insecure we call the delegate and stop the loop
            for interface in interfaces {
                let security: CWSecurity = interface.security()
                if security.rawValue == 0 {
                    wifiName = interface.ssid()
                    delegate?.unsecureWiFiDetected()
                    break
                }
            }
        case .cellular:
            PMLog.D("Reachable via Cellular")
        case .none:
            PMLog.D("Network not reachable")
        }
    }
}
