//
//  ZeroingData.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 4/27/17.
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

func Z() -> ZeroingData {
    return ZeroingData()
}

func Z(count: Int) -> ZeroingData {
    return ZeroingData(count: count)
}

func Z(bytes: UnsafePointer<UInt8>, count: Int) -> ZeroingData {
    return ZeroingData(bytes: bytes, count: count)
}

func Z(_ uint8: UInt8) -> ZeroingData {
    return ZeroingData(uInt8: uint8)
}

func Z(_ uint16: UInt16) -> ZeroingData {
    return ZeroingData(uInt16: uint16)
}

func Z(_ data: Data) -> ZeroingData {
    return ZeroingData(data: data)
}

//func Z(_ data: Data, _ offset: Int, _ count: Int) -> ZeroingData {
//    return ZeroingData(data: data, offset: offset, count: count)
//}

func Z(_ string: String, nullTerminated: Bool) -> ZeroingData {
    return ZeroingData(string: string, nullTerminated: nullTerminated)
}
