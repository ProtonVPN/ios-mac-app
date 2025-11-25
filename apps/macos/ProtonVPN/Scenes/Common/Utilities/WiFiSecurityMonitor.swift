//
//  WiFiSecurityMonitor.swift
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

import Combine
import CoreWLAN
import Foundation
import LegacyCommon
import Network
import VPNShared

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

    private let networkMonitor = NetworkPathMonitor()
    private static let monitorQueue = DispatchQueue(label: "ch.protonvpn.wifiSecurityMonitor.monitorQueue")
    private var networkMonitorCancellable: AnyCancellable?

    private let wifiClient: CWWiFiClient = .init()

    public private(set) var wifiName: String?

    weak var delegate: WiFiSecurityMonitorDelegate?

    deinit {
        networkMonitor.stop()
    }

    func startMonitoring() {
        networkMonitorCancellable = networkMonitor
            .pathSubject
            .removeDuplicates()
            .sink { [weak self] (nwPath: NWPath) in
                self?.reachabilityChanged(with: nwPath)
            }

        networkMonitor.start(onQueue: Self.monitorQueue)
    }

    func reachabilityChanged(with path: NWPath) {
        guard let interfaces = wifiClient.interfaces() else { return }

        if path.usesInterfaceType(.wifi) {
            log.info("Reachable via WiFi", category: .net)
            // just check all available wifi connections and if at least one of them is insecure we call the delegate and stop the loop
            for interface in interfaces {
                let security: CWSecurity = interface.security()
                if security.rawValue == 0 || security.rawValue == 1 {
                    wifiName = interface.ssid()
                    log.info("Unsecure WiFi detected", category: .net)
                    delegate?.unsecureWiFiDetected()
                    break
                }
            }
        } else if path.usesInterfaceType(.cellular) {
            log.info("Reachable via Cellular", category: .net)
        } else if path.usesInterfaceType(.wiredEthernet) {
            log.info("Reachable via wired ethernet", category: .net)
        } else if path.usesInterfaceType(.other) {
            log.info("Reachable via other interface", category: .net)
        } else if path.usesInterfaceType(.loopback) {
            log.info("Network not reachable", category: .net)
        }
    }
}

// MARK: WiFiSecurityMonitorFactory

extension DependencyContainer: WiFiSecurityMonitorFactory {
    func makeWiFiSecurityMonitor() -> WiFiSecurityMonitor {
        WiFiSecurityMonitor()
    }
}
