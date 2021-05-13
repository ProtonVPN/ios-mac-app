//
//  SecureRandom.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 2/3/17.
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
import Security.SecRandom
import __TunnelKitCore

enum SecureRandomError: Error {
    case randomGenerator
}

class SecureRandom {
    @available(*, deprecated)
    static func uint32FromBuffer() throws -> UInt32 {
        var randomBuffer = [UInt8](repeating: 0, count: 4)

        guard SecRandomCopyBytes(kSecRandomDefault, 4, &randomBuffer) == 0 else {
            throw SecureRandomError.randomGenerator
        }

        var randomNumber: UInt32 = 0
        for i in 0..<4 {
            let byte = randomBuffer[i]
            randomNumber |= (UInt32(byte) << UInt32(8 * i))
        }
        return randomNumber
    }
    
    static func uint32() throws -> UInt32 {
        var randomNumber: UInt32 = 0
        
        try withUnsafeMutablePointer(to: &randomNumber) {
            try $0.withMemoryRebound(to: UInt8.self, capacity: 4) { (randomBytes: UnsafeMutablePointer<UInt8>) -> Void in
                guard SecRandomCopyBytes(kSecRandomDefault, 4, randomBytes) == 0 else {
                    throw SecureRandomError.randomGenerator
                }
            }
        }
        
        return randomNumber
    }

    static func data(length: Int) throws -> Data {
        var randomData = Data(count: length)

        try randomData.withUnsafeMutableBytes {
            let randomBytes = $0.bytePointer
            guard SecRandomCopyBytes(kSecRandomDefault, length, randomBytes) == 0 else {
                throw SecureRandomError.randomGenerator
            }
        }
        
        return randomData
    }

    static func safeData(length: Int) throws -> ZeroingData {
        let randomBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer {
//            randomBytes.initialize(to: 0, count: length)
            bzero(randomBytes, length)
            randomBytes.deallocate()
        }
        
        guard SecRandomCopyBytes(kSecRandomDefault, length, randomBytes) == 0 else {
            throw SecureRandomError.randomGenerator
        }

        return Z(bytes: randomBytes, count: length)
    }
}
