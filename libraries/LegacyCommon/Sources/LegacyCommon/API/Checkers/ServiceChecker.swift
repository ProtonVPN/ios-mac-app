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

import Foundation

import CommonNetworking

class ServiceChecker {
    private static let forwardedAddress = "127.0.0.3"
    
    private let trafficCheckerQueue = DispatchQueue(label: "ch.protonvpn.traffic")
    private let networking: Networking
    private let alertService: CoreAlertService
    private let doh: DoHVPN

    private let refreshInterval: TimeInterval

    private var timer: Timer?
    private var p2pShown = false
    
    init(networking: Networking, alertService: CoreAlertService, doh: DoHVPN, refreshInterval: TimeInterval) {
        self.networking = networking
        self.alertService = alertService
        self.doh = doh
        self.refreshInterval = refreshInterval
        
        checkServices()
        
        timer = Timer(timeInterval: refreshInterval, target: self, selector: #selector(checkServices), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    deinit {
        stop()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func checkServices() {
        trafficCheckerQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            if !self.p2pShown {
                self.p2pBlocked()
                self.trafficForwarded()
            }
        }
    }
    
    private func p2pBlocked() {
        var urlRequest = URLRequest(url: URL(string: doh.statusHost + "/vpn_status")!)
        urlRequest.cachePolicy = .reloadIgnoringCacheData
        urlRequest.timeoutInterval = refreshInterval

        networking.request(urlRequest) { [weak self] (result: Result<(String), Error>) in
            switch result {
            case let .success(text):
                if text.starts(with: "<!--P2P_WARNING-->") {
                    self?.alertService.push(alert: P2pBlockedAlert())
                    self?.p2pShown = true
                } else if text.starts(with: "<!-- This is a blank file -->") {
                    log.debug("VPN status: connected through a VPN IP.")
                }
            case let .failure(error):
                log.error("\(error)", category: .ui)
            }
        }
    }
    
    private func trafficForwarded() {
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

        alertService.push(alert: P2pForwardedAlert())
        self.p2pShown = true
    }
}
