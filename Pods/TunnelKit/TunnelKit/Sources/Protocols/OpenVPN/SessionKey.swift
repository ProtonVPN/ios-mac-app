//
//  SessionKey.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 4/12/17.
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
import SwiftyBeaver
import __TunnelKitCore
import __TunnelKitOpenVPN

private let log = SwiftyBeaver.self

extension OpenVPN {
    class SessionKey {
        enum State {
            case invalid, hardReset, softReset, tls
        }
        
        enum ControlState {
            case preAuth, preIfConfig, connected
        }

        let id: UInt8 // 3-bit
        
        let timeout: TimeInterval
        
        let startTime: Date
        
        var state = State.invalid
        
        var controlState: ControlState?
        
        var tlsOptional: TLSBox?

        var tls: TLSBox {
            guard let tls = tlsOptional else {
                fatalError("TLSBox accessed when nil")
            }
            return tls
        }
        
        var dataPath: DataPath?
        
        private var isTLSConnected: Bool
        
        init(id: UInt8, timeout: TimeInterval) {
            self.id = id
            self.timeout = timeout

            startTime = Date()
            state = .invalid
            isTLSConnected = false
        }

        // Ruby: Key.hard_reset_timeout
        func didHardResetTimeOut(link: LinkInterface) -> Bool {
            return ((state == .hardReset) && (-startTime.timeIntervalSinceNow > CoreConfiguration.OpenVPN.hardResetTimeout))
        }
        
        // Ruby: Key.negotiate_timeout
        func didNegotiationTimeOut(link: LinkInterface) -> Bool {
            return ((controlState != .connected) && (-startTime.timeIntervalSinceNow > timeout))
        }
        
        // Ruby: Key.on_tls_connect
        func shouldOnTLSConnect() -> Bool {
            guard !isTLSConnected else {
                return false
            }
            if tls.isConnected() {
                isTLSConnected = true
            }
            return isTLSConnected
        }
        
        func encrypt(packets: [Data]) throws -> [Data]? {
            guard let dataPath = dataPath else {
                log.warning("Data: Set dataPath first")
                return nil
            }
            return try dataPath.encryptPackets(packets, key: id)
        }
        
        func decrypt(packets: [Data]) throws -> [Data]? {
            guard let dataPath = dataPath else {
                log.warning("Data: Set dataPath first")
                return nil
            }
            var keepAlive = false
            let decrypted = try dataPath.decryptPackets(packets, keepAlive: &keepAlive)
            if keepAlive {
                log.debug("Data: Received ping, do nothing")
            }
            return decrypted
        }
    }
}
