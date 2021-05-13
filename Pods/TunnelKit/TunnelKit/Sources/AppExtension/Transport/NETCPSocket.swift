//
//  NETCPInterface.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 4/15/18.
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
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

/// TCP implementation of a `GenericSocket` via NetworkExtension.
public class NETCPSocket: NSObject, GenericSocket {
    private static var linkContext = 0
    
    /// :nodoc:
    public let impl: NWTCPConnection
    
    /// :nodoc:
    public init(impl: NWTCPConnection) {
        self.impl = impl
        isActive = false
        isShutdown = false
    }
    
    // MARK: GenericSocket
    
    private weak var queue: DispatchQueue?
    
    private var isActive: Bool
    
    /// :nodoc:
    public private(set) var isShutdown: Bool
    
    /// :nodoc:
    public var remoteAddress: String? {
        return (impl.remoteAddress as? NWHostEndpoint)?.hostname
    }
    
    /// :nodoc:
    public var hasBetterPath: Bool {
        return impl.hasBetterPath
    }
    
    /// :nodoc:
    public weak var delegate: GenericSocketDelegate?
    
    /// :nodoc:
    public func observe(queue: DispatchQueue, activeTimeout: Int) {
        isActive = false
        
        self.queue = queue
        queue.schedule(after: .milliseconds(activeTimeout)) { [weak self] in
            guard let _self = self else {
                return
            }
            guard _self.isActive else {
                _self.delegate?.socketDidTimeout(_self)
                return
            }
        }
        impl.addObserver(self, forKeyPath: #keyPath(NWTCPConnection.state), options: [.initial, .new], context: &NETCPSocket.linkContext)
        impl.addObserver(self, forKeyPath: #keyPath(NWTCPConnection.hasBetterPath), options: .new, context: &NETCPSocket.linkContext)
    }
    
    /// :nodoc:
    public func unobserve() {
        impl.removeObserver(self, forKeyPath: #keyPath(NWTCPConnection.state), context: &NETCPSocket.linkContext)
        impl.removeObserver(self, forKeyPath: #keyPath(NWTCPConnection.hasBetterPath), context: &NETCPSocket.linkContext)
    }
    
    /// :nodoc:
    public func shutdown() {
        impl.writeClose()
        impl.cancel()
    }
    
    /// :nodoc:
    public func upgraded() -> GenericSocket? {
        guard impl.hasBetterPath else {
            return nil
        }
        return NETCPSocket(impl: NWTCPConnection(upgradeFor: impl))
    }
    
    // MARK: Connection KVO (any queue)
    
    /// :nodoc:
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard (context == &NETCPSocket.linkContext) else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
//        if let keyPath = keyPath {
//            log.debug("KVO change reported (\(anyPointer(object)).\(keyPath))")
//        }
        queue?.async {
            self.observeValueInTunnelQueue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func observeValueInTunnelQueue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        if let keyPath = keyPath {
//            log.debug("KVO change reported (\(anyPointer(object)).\(keyPath))")
//        }
        guard let impl = object as? NWTCPConnection, (impl == self.impl) else {
            log.warning("Discard KVO change from old socket")
            return
        }
        guard let keyPath = keyPath else {
            return
        }
        switch keyPath {
        case #keyPath(NWTCPConnection.state):
            if let resolvedEndpoint = impl.remoteAddress {
                log.debug("Socket state is \(impl.state) (endpoint: \(impl.endpoint.maskedDescription) -> \(resolvedEndpoint.maskedDescription))")
            } else {
                log.debug("Socket state is \(impl.state) (endpoint: \(impl.endpoint.maskedDescription) -> in progress)")
            }
            
            switch impl.state {
            case .connected:
                guard !isActive else {
                    return
                }
                isActive = true
                delegate?.socketDidBecomeActive(self)
                
            case .cancelled:
                isShutdown = true
                delegate?.socket(self, didShutdownWithFailure: false)
                
            case .disconnected:
                isShutdown = true
                delegate?.socket(self, didShutdownWithFailure: true)
                
            default:
                break
            }
            
        case #keyPath(NWTCPConnection.hasBetterPath):
            guard impl.hasBetterPath else {
                break
            }
            log.debug("Socket has a better path")
            delegate?.socketHasBetterPath(self)
            
        default:
            break
        }
    }
}

/// :nodoc:
extension NETCPSocket {
    public override var description: String {
        guard let hostEndpoint = impl.endpoint as? NWHostEndpoint else {
            return impl.endpoint.maskedDescription
        }
        return "\(hostEndpoint.hostname.maskedDescription):\(hostEndpoint.port)"
    }
}
