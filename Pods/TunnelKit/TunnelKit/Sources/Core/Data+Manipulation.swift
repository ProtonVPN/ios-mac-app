//
//  Data+Manipulation.swift
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

// hex -> Data conversion code from: http://stackoverflow.com/questions/32231926/nsdata-from-hex-string
// Data -> hex conversion code from: http://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift

extension UnicodeScalar {
    var hexNibble: UInt8 {
        let value = self.value
        if 48 <= value && value <= 57 {
            return UInt8(value - 48)
        }
        else if 65 <= value && value <= 70 {
            return UInt8(value - 55)
        }
        else if 97 <= value && value <= 102 {
            return UInt8(value - 87)
        }
        fatalError("\(self) not a legal hex nibble")
    }
}

extension Data {
    init(hex: String) {
        let scalars = hex.unicodeScalars
        var bytes = Array<UInt8>(repeating: 0, count: (scalars.count + 1) >> 1)
        for (index, scalar) in scalars.enumerated() {
            var nibble = scalar.hexNibble
            if index & 1 == 0 {
                nibble <<= 4
            }
            bytes[index >> 1] |= nibble
        }
        self = Data(bytes)
    }

    func toHex() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    mutating func zero() {
        resetBytes(in: 0..<count)
    }

    mutating func zero(from: Int, to: Int) {
        resetBytes(in: from..<to)
    }
}

extension Data {
    mutating func append(_ value: UInt16) {
        var localValue = value
        let buffer = withUnsafePointer(to: &localValue) {
            return UnsafeBufferPointer(start: $0, count: 1)
        }
        append(buffer)
    }
    
    mutating func append(_ value: UInt32) {
        var localValue = value
        let buffer = withUnsafePointer(to: &localValue) {
            return UnsafeBufferPointer(start: $0, count: 1)
        }
        append(buffer)
    }
    
    mutating func append(_ value: UInt64) {
        var localValue = value
        let buffer = withUnsafePointer(to: &localValue) {
            return UnsafeBufferPointer(start: $0, count: 1)
        }
        append(buffer)
    }
    
    mutating func append(nullTerminatedString: String) {
        append(nullTerminatedString.data(using: .ascii)!)
        append(UInt8(0))
    }

    func nullTerminatedString(from: Int) -> String? {
        var nullOffset: Int?
        for i in from..<count {
            if (self[i] == 0) {
                nullOffset = i
                break
            }
        }
        guard let to = nullOffset else {
            return nil
        }
        return String(data: subdata(in: from..<to), encoding: .ascii)
    }

    // best
    func UInt16Value(from: Int) -> UInt16 {
        var value: UInt16 = 0
        for i in 0..<2 {
            let byte = self[from + i]
//            print("byte: \(String(format: "%x", byte))")
            value |= (UInt16(byte) << UInt16(8 * i))
        }
//        print("value: \(String(format: "%x", value))")
        return value
    }
    
    @available(*, deprecated)
    func UInt16ValueFromPointers(from: Int) -> UInt16 {
        return subdata(in: from..<(from + 2)).withUnsafeBytes { $0.pointee }
    }

    @available(*, deprecated)
    func UInt16ValueFromReboundPointers(from: Int) -> UInt16 {
        let data = subdata(in: from..<(from + 2))
//        print("data: \(data.toHex())")
        let value = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UInt16 in
            bytes.withMemoryRebound(to: UInt16.self, capacity: 1) {
                $0.pointee
            }
        }
//        print("value: \(String(format: "%x", value))")
        return value
    }
    
    @available(*, deprecated)
    func UInt32ValueFromBuffer(from: Int) -> UInt32 {
        var value: UInt32 = 0
        for i in 0..<4 {
            let byte = self[from + i]
//            print("byte: \(String(format: "%x", byte))")
            value |= (UInt32(byte) << UInt32(8 * i))
        }
//        print("value: \(String(format: "%x", value))")
        return value
    }
    
    // best
    func UInt32Value(from: Int) -> UInt32 {
        return subdata(in: from..<(from + 4)).withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
    }

    @available(*, deprecated)
    func UInt32ValueFromReboundPointers(from: Int) -> UInt32 {
        let data = subdata(in: from..<(from + 4))
//        print("data: \(data.toHex())")
        let value = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UInt32 in
            bytes.withMemoryRebound(to: UInt32.self, capacity: 1) {
                $0.pointee
            }
        }
//        print("value: \(String(format: "%x", value))")
        return value
    }

    func networkUInt16Value(from: Int) -> UInt16 {
        return UInt16(bigEndian: subdata(in: from..<(from + 2)).withUnsafeBytes {
            $0.load(as: UInt16.self)
        })
    }

    func networkUInt32Value(from: Int) -> UInt32 {
        return UInt32(bigEndian: subdata(in: from..<(from + 4)).withUnsafeBytes {
            $0.load(as: UInt32.self)
        })
    }
}

extension Data {
    func subdata(offset: Int, count: Int) -> Data {
        return subdata(in: offset..<(offset + count))
    }
}

extension Array where Element == Data {
    var flatCount: Int {
        return reduce(0) { $0 + $1.count }
    }
}

extension UnsafeRawBufferPointer {
    var bytePointer: UnsafePointer<Element> {
        return bindMemory(to: Element.self).baseAddress!
    }
}

extension UnsafeMutableRawBufferPointer {
    var bytePointer: UnsafeMutablePointer<Element> {
        return bindMemory(to: Element.self).baseAddress!
    }
}
