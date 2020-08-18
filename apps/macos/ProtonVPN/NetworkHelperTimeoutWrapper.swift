//
//  NetworkHelperWrapper.swift
//  ProtonVPN - Created on 2020-08-04.
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
import vpncore

/// Network helper wrapper that checks if helper has returned any error.
/// In case real helper doesn't return, error handler will be called.
class NetworkHelperTimeoutWrapper: NetworkHelperProtocol {
    
    private let errorTimeOut: DispatchTimeInterval = .seconds(3)
    
    private let helper: NetworkHelperProtocol
    private let queue = DispatchQueue(label: "NetworkHelperWrapper", qos: .default, attributes: .init(), autoreleaseFrequency: .workItem, target: nil)
    
    typealias ErrorHandler = (Error) -> Void
    private let errorHandler: ErrorHandler
    
    enum NHWError: Error {
        case timeOut
    }
    
    public init(_ helper: NetworkHelperProtocol, errorHandler: @escaping ErrorHandler) {
        self.helper = helper
        self.errorHandler = errorHandler
    }
    
    func getVersion(completion: @escaping (String) -> Void) {
        var completionsSucceeded = false
        queue.asyncAfter(deadline: .now() + errorTimeOut, execute: {
            guard !completionsSucceeded else {
                return
            }
            PMLog.D("NetworkHelper.getVersion timeout")
            self.errorHandler(NHWError.timeOut)
        })
        
        helper.getVersion(completion: { input in
            guard !completionsSucceeded else {
                PMLog.D("NetworkHelper.getVersion returned after timeout: \(input)")
                return
            }
            completionsSucceeded = true
            completion(input)
        })
    }
    
    func unload(completion: @escaping (NSNumber) -> Void) {
        helper.unload(completion: completion)
    }
    
    func anyFirewallEnabled(completion: @escaping (NSNumber) -> Void) {
        helper.anyFirewallEnabled(completion: completion)
    }
    
    func firewallEnabled(forServer address: String, completion: @escaping (NSNumber) -> Void) {
        var completionsSucceeded = false
        queue.asyncAfter(deadline: .now() + errorTimeOut, execute: {
            guard !completionsSucceeded else {
                return
            }
            PMLog.D("NetworkHelper.firewallEnabled timeout")
            self.errorHandler(NHWError.timeOut)
        })
        
        helper.firewallEnabled(forServer: address, completion: { input in
            guard !completionsSucceeded else {
                PMLog.D("NetworkHelper.firewallEnabled returned after timeout: \(input)")
                return
            }
            completionsSucceeded = true
            completion(input)
        })
    }
    
    func enableFirewall(with file: URL, completion: @escaping (NSNumber) -> Void) {
        var completionsSucceeded = false
        queue.asyncAfter(deadline: .now() + errorTimeOut, execute: {
            guard !completionsSucceeded else {
                return
            }
            PMLog.D("NetworkHelper.enableFirewall timeout")
            self.errorHandler(NHWError.timeOut)
        })
        
        helper.enableFirewall(with: file, completion: { input in
            guard !completionsSucceeded else {
                PMLog.D("NetworkHelper.enableFirewall returned after timeout: \(input)")
                return
            }
            completionsSucceeded = true
            completion(input)
        })
    }
    
    func disableFirewall(completion: @escaping (NSNumber) -> Void) {
        helper.disableFirewall(completion: completion)
    }
    
}
