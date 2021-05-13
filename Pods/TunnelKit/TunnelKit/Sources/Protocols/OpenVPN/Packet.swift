//
//  Packet.swift
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
import __TunnelKitOpenVPN

/// :nodoc:
extension ControlPacket {

    /// :nodoc:
    open override var description: String {
        var msg: [String] = ["\(code) | \(key)"]
        msg.append("sid: \(sessionId.toHex())")
        if let ackIds = ackIds, let ackRemoteSessionId = ackRemoteSessionId {
            msg.append("acks: {\(ackIds), \(ackRemoteSessionId.toHex())}")
        }
        if !isAck {
            msg.append("pid: \(packetId)")
        }
        if let payload = payload {
            if CoreConfiguration.logsSensitiveData {
                msg.append("[\(payload.count) bytes] -> \(payload.toHex())")
            } else {
                msg.append("[\(payload.count) bytes]")
            }
        }
        return "{\(msg.joined(separator: ", "))}"
    }
}

extension OpenVPN {
    class DataPacket {
        static let pingString = Data(hex: "2a187bf3641eb4cb07ed2d0a981fc748")
    }

    enum OCCPacket: UInt8 {
        case exit = 0x06
        
        private static let magicString = Data(hex: "287f346bd4ef7a812d56b8d3afc5459c")

        func serialized(_ info: Any? = nil) -> Data {
            var data = OCCPacket.magicString
            data.append(rawValue)
            switch self {
            case .exit:
                break // nothing more
            }
            return data
        }
    }
}

/// :nodoc:
extension PacketCode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .softResetV1:          return "SOFT_RESET_V1"
        case .controlV1:            return "CONTROL_V1"
        case .ackV1:                return "ACK_V1"
        case .dataV1:               return "DATA_V1"
        case .hardResetClientV2:    return "HARD_RESET_CLIENT_V2"
        case .hardResetServerV2:    return "HARD_RESET_SERVER_V2"
        case .dataV2:               return "DATA_V2"
        case .unknown:              return "UNKNOWN"
        @unknown default:           return "UNKNOWN"
        }
    }
}
