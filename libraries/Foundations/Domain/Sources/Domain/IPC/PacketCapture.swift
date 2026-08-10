//
//  Created on 11/05/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public enum PacketCaptureInterruptionReason: UInt64 {
    case connectionTerminated = 0 // coincides with `zeroAll()`
    case explicitStop
    case timerHit
    case storageLimitHit
}

extension PacketCaptureInterruptionReason: Codable {}
extension PacketCaptureInterruptionReason: Sendable {}

public extension ProTUNMessage.Request {
    /// IPC request to start/stop the PCAP feature. The `.start` case is only used in the scenario where a tunnel
    /// already exists. If the tunnel doesn't exist, the PCAP gets started by setting the file location in the provider
    /// configuration.
    enum PcapRequest: Codable {
        case start(fileURL: URL)
        case stop
    }
}

extension ProTUNMessage.Request.PcapRequest: Sendable {}
extension ProTUNMessage.Request.PcapRequest: Equatable {}

public struct URLWithSize: Codable, Equatable, Sendable {
    public let url: URL
    public let size: Int
    public init(url: URL, size: Int) {
        self.url = url
        self.size = size
    }
}

public struct URLWithDate: Codable, Equatable, Sendable {
    public let url: URL
    public let date: Date
    public init(url: URL, date: Date) {
        self.url = url
        self.date = date
    }
}
