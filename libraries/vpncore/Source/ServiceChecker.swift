//
//  ServiceChecker.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Alamofire
import Foundation

class ServiceChecker {
    
    private let trafficCheckerQueue = DispatchQueue(label: "ch.protonvpn.traffic")
    private let alamofireWrapper: AlamofireWrapper
    private let alertService: CoreAlertService
    private var timer: Timer?
    private var p2pShown = false
    
    init(alamofireWrapper: AlamofireWrapper, alertService: CoreAlertService) {
        self.alamofireWrapper = alamofireWrapper
        self.alertService = alertService
        
        checkServices()
        
        timer = Timer(timeInterval: 30, target: self, selector: #selector(checkServices), userInfo: nil, repeats: true)
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
            guard let `self` = self else { return }
            
            if !self.p2pShown {
                self.p2pBlocked()
                self.trafficForwarded()
            }
        }
    }
    
    private func p2pBlocked() {
        let success: (String) -> Void = { [weak self] result in
            if result.contains("<!--P2P_WARNING-->") {
                self?.alertService.push(alert: P2pBlockedAlert())
                self?.p2pShown = true
            }
        }
        let failure: (Error) -> Void = { error in
            PMLog.ET(error.localizedDescription)
        }
        
        alamofireWrapper.request(ChecksRouter.status, success: success, failure: failure)
    }
    
    private func trafficForwarded() {
        let host = CFHostCreateWithName(nil, "dmca-protection.protonvpn.com" as CFString).takeRetainedValue()
        if CFHostStartInfoResolution(host, .addresses, nil) {
            // Ignore warning
            if let address = (CFHostGetAddressing(host, nil)?.takeUnretainedValue() as? NSArray)?.firstObject as? NSData {
                var addressPointer = [Int8](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    address.bytes.assumingMemoryBound(to: sockaddr.self),
                    socklen_t(address.length),
                    &addressPointer,
                    socklen_t(addressPointer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                    ) == 0 {
                    let ipAddress = String(cString: addressPointer)
                    if ipAddress == "127.0.0.3" {
                        alertService.push(alert: P2pForwardedAlert())
                        self.p2pShown = true
                    }
                }
            }
        }
    }
}
