//
//  ServiceChecker.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Foundation
import VPNAppCore

/// Defines the types of service alerts that can be detected
public enum ServiceAlertType: Sendable {
    case p2pBlocked
    case p2pForwarded
}

public class ServiceChecker {
    // P2P (need to move to LocalAgent for this - VPNAPPL-2688)
    public static let defaultRefreshInterval: TimeInterval = 90

    private static let forwardedAddress = "127.0.0.3"

    @Dependency(\.networking) private var networking
    private let doh: DoHVPN

    private let refreshInterval: TimeInterval

    private var p2pShown = false
    private var checkTask: Task<Void, Never>?

    private let alertContinuation: AsyncStream<ServiceAlertType>.Continuation

    /// Stream of service alerts detected by the checker
    public let alerts: AsyncStream<ServiceAlertType>

    // MARK: - Init

    public init(
        refreshInterval: TimeInterval = ServiceChecker.defaultRefreshInterval
    ) {
        @Dependency(\.dohConfiguration) var doh
        self.doh = doh
        self.refreshInterval = refreshInterval

        // Create the async stream
        var continuation: AsyncStream<ServiceAlertType>.Continuation!
        self.alerts = AsyncStream { continuation = $0 }
        self.alertContinuation = continuation

        // Start the checking task
        startChecking()
    }

    deinit {
        stop()
    }

    public func stop() {
        checkTask?.cancel()
        checkTask = nil
        alertContinuation.finish()
    }

    // MARK: - Private

    private func startChecking() {
        checkTask = Task { [weak self] in
            guard let self else { return }

            // Perform initial check immediately
            await checkServices()

            // Then check periodically
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))

                guard !Task.isCancelled else { break }
                await checkServices()
            }
        }
    }

    private func checkServices() async {
        guard !p2pShown else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.p2pBlocked() }
            group.addTask { await self.trafficForwarded() }
        }
    }

    private func p2pBlocked() async {
        var urlRequest = URLRequest(url: URL(string: doh.statusHost + "/vpn_status")!)
        urlRequest.cachePolicy = .reloadIgnoringCacheData
        urlRequest.timeoutInterval = refreshInterval

        let result: Result<String, Error> = await withCheckedContinuation { continuation in
            networking.request(urlRequest) { (result: Result<String, Error>) in
                continuation.resume(returning: result)
            }
        }

        switch result {
        case let .success(text):
            if text.starts(with: "<!--P2P_WARNING-->") {
                alertContinuation.yield(.p2pBlocked)
                p2pShown = true
            } else if text.starts(with: "<!-- This is a blank file -->") {
                log.debug("VPN status: connected through a VPN IP.")
            }
        case let .failure(error):
            log.error("\(error)", category: .ui)
        }
    }

    private func trafficForwarded() async {
        let host = CFHostCreateWithName(nil, "dmca-protection.protonvpn.com" as CFString).takeRetainedValue()

        guard CFHostStartInfoResolution(host, .addresses, nil),
              let addresses = CFHostGetAddressing(host, nil)?.takeUnretainedValue() as? NSArray,
              let address = (addresses.firstObject as? NSData) as? Data else {
            return
        }

        let ipAddress = address.withUnsafeBytes { addressBytes -> String? in
            let addressSize = Int(NI_MAXHOST)
            let addressPointer = UnsafeMutablePointer<Int8>.allocate(capacity: addressSize)
            defer { addressPointer.deallocate() }

            guard getnameinfo(
                addressBytes.assumingMemoryBound(to: sockaddr.self).baseAddress,
                socklen_t(address.count),
                addressPointer,
                socklen_t(addressSize),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else {
                return nil
            }

            return String(cString: addressPointer)
        }

        guard ipAddress == Self.forwardedAddress else {
            return
        }

        alertContinuation.yield(.p2pForwarded)
        p2pShown = true
    }
}
