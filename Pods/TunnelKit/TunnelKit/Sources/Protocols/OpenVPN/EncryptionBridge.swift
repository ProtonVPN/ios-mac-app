//
//  EncryptionBridge.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 2/8/17.
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
import __TunnelKitCore
import __TunnelKitOpenVPN

extension OpenVPN {
    class EncryptionBridge {
        private static let maxHmacLength = 100
        
        private let box: CryptoBox
        
        // Ruby: keys_prf
        private static func keysPRF(
            _ label: String,
            _ secret: ZeroingData,
            _ clientSeed: ZeroingData,
            _ serverSeed: ZeroingData,
            _ clientSessionId: Data?,
            _ serverSessionId: Data?,
            _ size: Int) throws -> ZeroingData {
            
            let seed = Z(label, nullTerminated: false)
            seed.append(clientSeed)
            seed.append(serverSeed)
            if let csi = clientSessionId {
                seed.append(Z(csi))
            }
            if let ssi = serverSessionId {
                seed.append(Z(ssi))
            }
            let len = secret.count / 2
            let lenx = len + (secret.count & 1)
            let secret1 = secret.withOffset(0, count: lenx)
            let secret2 = secret.withOffset(len, count: lenx)
            
            let hash1 = try keysHash("md5", secret1, seed, size)
            let hash2 = try keysHash("sha1", secret2, seed, size)
            
            let prf = Z()
            for i in 0..<hash1.count {
                let h1 = hash1.bytes[i]
                let h2 = hash2.bytes[i]
                
                prf.append(Z(h1 ^ h2))
            }
            return prf
        }
        
        // Ruby: keys_hash
        private static func keysHash(_ digestName: String, _ secret: ZeroingData, _ seed: ZeroingData, _ size: Int) throws -> ZeroingData {
            let out = Z()
            let buffer = Z(count: EncryptionBridge.maxHmacLength)
            var chain = try EncryptionBridge.hmac(buffer, digestName, secret, seed)
            while (out.count < size) {
                out.append(try EncryptionBridge.hmac(buffer, digestName, secret, chain.appending(seed)))
                chain = try EncryptionBridge.hmac(buffer, digestName, secret, chain)
            }
            return out.withOffset(0, count: size)
        }
        
        // Ruby: hmac
        private static func hmac(_ buffer: ZeroingData, _ digestName: String, _ secret: ZeroingData, _ data: ZeroingData) throws -> ZeroingData {
            var length = 0
            
            try CryptoBox.hmac(
                withDigestName: digestName,
                secret: secret.bytes,
                secretLength: secret.count,
                data: data.bytes,
                dataLength: data.count,
                hmac: buffer.mutableBytes,
                hmacLength: &length
            )
            
            return buffer.withOffset(0, count: length)
        }
        
        convenience init(_ cipher: Cipher, _ digest: Digest, _ auth: Authenticator,
                         _ sessionId: Data, _ remoteSessionId: Data) throws {
            
            guard let serverRandom1 = auth.serverRandom1, let serverRandom2 = auth.serverRandom2 else {
                fatalError("Configuring encryption without server randoms")
            }
            
            let masterData = try EncryptionBridge.keysPRF(
                CoreConfiguration.OpenVPN.label1, auth.preMaster, auth.random1,
                serverRandom1, nil, nil,
                CoreConfiguration.OpenVPN.preMasterLength
            )
            
            let keysData = try EncryptionBridge.keysPRF(
                CoreConfiguration.OpenVPN.label2, masterData, auth.random2,
                serverRandom2, sessionId, remoteSessionId,
                CoreConfiguration.OpenVPN.keysCount * CoreConfiguration.OpenVPN.keyLength
            )
            
            var keysArray = [ZeroingData]()
            for i in 0..<CoreConfiguration.OpenVPN.keysCount {
                let offset = i * CoreConfiguration.OpenVPN.keyLength
                let zbuf = keysData.withOffset(offset, count: CoreConfiguration.OpenVPN.keyLength)
                keysArray.append(zbuf)
            }
            
            let cipherEncKey = keysArray[0]
            let hmacEncKey = keysArray[1]
            let cipherDecKey = keysArray[2]
            let hmacDecKey = keysArray[3]
            
            try self.init(cipher, digest, cipherEncKey, cipherDecKey, hmacEncKey, hmacDecKey)
        }
        
        init(_ cipher: Cipher, _ digest: Digest, _ cipherEncKey: ZeroingData, _ cipherDecKey: ZeroingData, _ hmacEncKey: ZeroingData, _ hmacDecKey: ZeroingData) throws {
            box = CryptoBox(cipherAlgorithm: cipher.rawValue, digestAlgorithm: digest.rawValue)
            try box.configure(
                withCipherEncKey: cipherEncKey,
                cipherDecKey: cipherDecKey,
                hmacEncKey: hmacEncKey,
                hmacDecKey: hmacDecKey
            )
        }
        
        func encrypter() -> DataPathEncrypter {
            return box.encrypter().dataPathEncrypter()
        }

        func decrypter() -> DataPathDecrypter {
            return box.decrypter().dataPathDecrypter()
        }
    }
}
