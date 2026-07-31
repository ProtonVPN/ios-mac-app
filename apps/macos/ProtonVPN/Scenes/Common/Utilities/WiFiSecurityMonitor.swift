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

// MARK: - Delegate

public protocol WiFiSecurityMonitorDelegate: AnyObject {
    /// Called (on the main queue) when the device is connected via an insecure Wi-Fi network
    func unsecureWiFiDetected()
    /// Called (on the main queue) when a previously reported insecure connection is gone,
    /// e.g. the user moved to a secure Wi-Fi, cellular, or wired connection
    func secureConnectionRestored()
}

// MARK: - WiFiSecurityMonitor

/// Monitors network path changes and reports connections over insecure Wi-Fi
/// (open, WEP, or dynamic WEP networks).
public final class WiFiSecurityMonitor: NSObject {
    // MARK: Configuration

    /// Security modes treated as insecure. Everything else (WPA/WPA2/WPA3,
    /// personal or enterprise) is considered acceptable. `.unknown` is
    /// explicitly *not* in this set: CoreWLAN reports `.unknown`
    /// (`NSIntegerMax`) when the interface is not associated with a network,
    /// which must not trigger a false positive.
    private static let insecureModes: Set<CWSecurity> = [.none, .WEP, .dynamicWEP]

    // MARK: Dependencies

    private let networkMonitor = NetworkPathMonitor.shared
    private var networkMonitorCancellable: AnyCancellable?
    private let wifiClient: CWWiFiClient = .shared()

    // MARK: State

    public weak var delegate: WiFiSecurityMonitorDelegate?
    public private(set) var wifiName: String?

    /// Fingerprint of the last insecure network we reported, used to avoid
    /// firing the delegate repeatedly for the same network on flapping
    /// connections. `NWPath`'s `removeDuplicates()` alone doesn't cover
    /// reconnects to the same (or a different) insecure SSID.
    private var lastReportedInsecureNetwork: NetworkFingerprint?

    private struct NetworkFingerprint: Equatable {
        let ssid: String?
        let interfaceName: String?
        let security: CWSecurity
    }

    // MARK: Lifecycle

    deinit {
        stopMonitoring()
    }

    // MARK: Public API

    public func startMonitoring() {
        networkMonitorCancellable = networkMonitor
            .pathSubject
            .removeDuplicates()
            // NWPathMonitor delivers on a background queue; hop to main so
            // state mutation and delegate callbacks are main-thread safe.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (path: NWPath) in
                self?.reachabilityChanged(with: path)
            }

        networkMonitor.start()
    }

    public func stopMonitoring() {
        networkMonitorCancellable?.cancel()
        networkMonitorCancellable = nil
        networkMonitor.stop()
    }

    // MARK: Path handling

    private func reachabilityChanged(with path: NWPath) {
        guard path.status == .satisfied else {
            log.info("Network not reachable", category: .net)
            clearInsecureStateIfNeeded()
            return
        }

        guard path.usesInterfaceType(.wifi) else {
            if path.usesInterfaceType(.cellular) {
                log.info("Reachable via Cellular", category: .net)
            } else if path.usesInterfaceType(.wiredEthernet) {
                log.info("Reachable via wired ethernet", category: .net)
            } else if path.usesInterfaceType(.loopback) {
                log.info("Reachable via loopback", category: .net)
            } else {
                log.info("Reachable via other interface", category: .net)
            }
            // Not on Wi-Fi anymore: clear any previous insecure state.
            clearInsecureStateIfNeeded()
            return
        }

        log.info("Reachable via WiFi", category: .net)
        evaluateWiFiInterfaces()
    }

    private func evaluateWiFiInterfaces() {
        guard let interfaces = wifiClient.interfaces(), !interfaces.isEmpty else {
            clearInsecureStateIfNeeded()
            return
        }

        // Check all available Wi-Fi interfaces; report the first insecure one.
        guard let insecureInterface = interfaces.first(where: { interface in
            Self.insecureModes.contains(interface.security())
        }) else {
            // All associated interfaces are secure.
            clearInsecureStateIfNeeded()
            return
        }

        // ssid() returns nil on macOS 14+ without location authorization;
        // fall back to the BSD interface name so the UI has something to show.
        let ssid = insecureInterface.ssid()

        let fingerprint = NetworkFingerprint(
            ssid: ssid,
            interfaceName: insecureInterface.interfaceName,
            security: insecureInterface.security()
        )

        // Don't re-notify for the same network we already reported.
        guard fingerprint != lastReportedInsecureNetwork else { return }
        lastReportedInsecureNetwork = fingerprint

        log.info("Unsecure WiFi detected", category: .net)
        delegate?.unsecureWiFiDetected()
    }

    /// Clears stale state and notifies the delegate once when leaving a
    /// previously reported insecure network.
    private func clearInsecureStateIfNeeded() {
        guard lastReportedInsecureNetwork != nil else { return }
        lastReportedInsecureNetwork = nil
        delegate?.secureConnectionRestored()
    }
}

// MARK: WiFiSecurityMonitorFactory

extension DependencyContainer: WiFiSecurityMonitorFactory {
    func makeWiFiSecurityMonitor() -> WiFiSecurityMonitor {
        WiFiSecurityMonitor()
    }
}
