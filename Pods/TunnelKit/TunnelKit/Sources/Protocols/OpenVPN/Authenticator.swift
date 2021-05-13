//
//  Authenticator.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 2/9/17.
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

fileprivate extension ZeroingData {
    func appendSized(_ buf: ZeroingData) {
        append(Z(UInt16(buf.count).bigEndian))
        append(buf)
    }
}

extension OpenVPN {
    class Authenticator {
        private var controlBuffer: ZeroingData
        
        private(set) var preMaster: ZeroingData
        
        private(set) var random1: ZeroingData
        
        private(set) var random2: ZeroingData
        
        private(set) var serverRandom1: ZeroingData?

        private(set) var serverRandom2: ZeroingData?

        private(set) var username: ZeroingData?
        
        private(set) var password: ZeroingData?
        
        var withLocalOptions: Bool
        
        init(_ username: String?, _ password: String?) throws {
            preMaster = try SecureRandom.safeData(length: CoreConfiguration.OpenVPN.preMasterLength)
            random1 = try SecureRandom.safeData(length: CoreConfiguration.OpenVPN.randomLength)
            random2 = try SecureRandom.safeData(length: CoreConfiguration.OpenVPN.randomLength)
            
            // XXX: not 100% secure, can't erase input username/password
            if let username = username, let password = password {
                self.username = Z(username, nullTerminated: true)
                self.password = Z(password, nullTerminated: true)
            } else {
                self.username = nil
                self.password = nil
            }
            
            withLocalOptions = true
            
            controlBuffer = Z()
        }
        
        func reset() {
            controlBuffer.zero()
            preMaster.zero()
            random1.zero()
            random2.zero()
            serverRandom1?.zero()
            serverRandom2?.zero()
            username = nil
            password = nil
        }
        
        // MARK: Authentication request

        // Ruby: on_tls_connect
        func putAuth(into: TLSBox, options: Configuration) throws {
            let raw = Z(ProtocolMacros.tlsPrefix)
            
            // local keys
            raw.append(preMaster)
            raw.append(random1)
            raw.append(random2)
            
            // options string
            let optsString: String
            if withLocalOptions {
                var opts = [
                    "V4",
                    "dev-type tun"
                ]
                if let comp = options.compressionFraming {
                    switch comp {
                    case .compLZO:
                        opts.append("comp-lzo")
                        
                    case .compress:
                        opts.append("compress")
                        
                    default:
                        break
                    }
                }
                if let direction = options.tlsWrap?.key.direction?.rawValue {
                    opts.append("keydir \(direction)")
                }
                opts.append("cipher \(options.fallbackCipher.rawValue)")
                opts.append("auth \(options.fallbackDigest.rawValue)")
                opts.append("keysize \(options.fallbackCipher.keySize)")
                if let strategy = options.tlsWrap?.strategy {
                    opts.append("tls-\(strategy)")
                }
                opts.append("key-method 2")
                opts.append("tls-client")
                optsString = opts.joined(separator: ",")
            } else {
                optsString = "V0 UNDEF"
            }
            log.debug("TLS.auth: Local options: \(optsString)")
            raw.appendSized(Z(optsString, nullTerminated: true))
            
            // credentials
            if let username = username, let password = password {
                raw.appendSized(username)
                raw.appendSized(password)
            } else {
                raw.append(Z(UInt16(0)))
                raw.append(Z(UInt16(0)))
            }

            // peer info
            var extra: [String: String] = [:]
            if let dataCiphers = options.dataCiphers {
                extra["IV_CIPHERS"] = dataCiphers.map { $0.rawValue }.joined(separator: ":")
            }
            raw.appendSized(Z(CoreConfiguration.OpenVPN.peerInfo(extra: extra), nullTerminated: true))

            if CoreConfiguration.logsSensitiveData {
                log.debug("TLS.auth: Put plaintext (\(raw.count) bytes): \(raw.toHex())")
            } else {
                log.debug("TLS.auth: Put plaintext (\(raw.count) bytes)")
            }
            
            try into.putRawPlainText(raw.bytes, length: raw.count)
        }
        
        // MARK: Server replies

        func appendControlData(_ data: ZeroingData) {
            controlBuffer.append(data)
        }
        
        func parseAuthReply() throws -> Bool {
            let prefixLength = ProtocolMacros.tlsPrefix.count

            // TLS prefix + random (x2) + opts length [+ opts]
            guard (controlBuffer.count >= prefixLength + 2 * CoreConfiguration.OpenVPN.randomLength + 2) else {
                return false
            }
            
            let prefix = controlBuffer.withOffset(0, count: prefixLength)
            guard prefix.isEqual(to: ProtocolMacros.tlsPrefix) else {
                throw OpenVPNError.wrongControlDataPrefix
            }
            
            var offset = ProtocolMacros.tlsPrefix.count
            
            let serverRandom1 = controlBuffer.withOffset(offset, count: CoreConfiguration.OpenVPN.randomLength)
            offset += CoreConfiguration.OpenVPN.randomLength
            
            let serverRandom2 = controlBuffer.withOffset(offset, count: CoreConfiguration.OpenVPN.randomLength)
            offset += CoreConfiguration.OpenVPN.randomLength
            
            let serverOptsLength = Int(controlBuffer.networkUInt16Value(fromOffset: offset))
            offset += 2
            
            guard controlBuffer.count >= offset + serverOptsLength else {
                return false
            }
            let serverOpts = controlBuffer.withOffset(offset, count: serverOptsLength)
            offset += serverOptsLength

            if CoreConfiguration.logsSensitiveData {
                log.debug("TLS.auth: Parsed server random: [\(serverRandom1.toHex()), \(serverRandom2.toHex())]")
            } else {
                log.debug("TLS.auth: Parsed server random")
            }
            
            if let serverOptsString = serverOpts.nullTerminatedString(fromOffset: 0) {
                log.debug("TLS.auth: Parsed server options: \"\(serverOptsString)\"")
            }
            
            self.serverRandom1 = serverRandom1
            self.serverRandom2 = serverRandom2
            controlBuffer.remove(untilOffset: offset)
            
            return true
        }
        
        func parseMessages() -> [String] {
            var messages = [String]()
            var offset = 0
            
            while true {
                guard let msg = controlBuffer.nullTerminatedString(fromOffset: offset) else {
                    break
                }
                messages.append(msg)
                offset += msg.count + 1
            }

            controlBuffer.remove(untilOffset: offset)

            return messages
        }
    }
}
