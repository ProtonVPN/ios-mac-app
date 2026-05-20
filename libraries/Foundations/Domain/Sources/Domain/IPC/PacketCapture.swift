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
import IPCErgonomics

public enum PacketCaptureInterruptionReason: UInt64 {
    case unknown
    case explicitStop
    case timerHit
    case storageLimitHit
}

extension PacketCaptureInterruptionReason: Codable {}
extension PacketCaptureInterruptionReason: Sendable {}

public enum CaptureSession: Equatable, Codable {
    public static let storageKey: String = "PcapSession"

    case noSession
    case pendingConnection
    case sessionStarted(to: URL, at: Date)
    case sessionEnded(to: URL, fileSize: Int64, reason: PacketCaptureInterruptionReason)
}

public extension IPCNotifications.Notification {
    static let pcapInterrupted: Self = .init(name: "ch.protonvpn.protun.pcapInterrupted")
    static let pcapSessionChanged: Self = .init(name: "ch.protonvpn.protun.pcapSessionChanged")
}

public extension ProTUNMessage.Request {
    enum PcapRequest: Codable {
        case fileURL
        case isRecording
        case cleanup
        case toggleCapture
    }
}

extension ProTUNMessage.Request.PcapRequest: Sendable {}

public extension ProTUNMessage.Response {
    enum PcapUpdate: Codable {
        case fileURL(URL?)
        case isRecording(Bool)
        case cleanupResult(CodableResult<Bool, Error>)
        case captureStartResult(CodableResult<URL, Error>)
        case captureFinished(URL, Int64)
    }
}

extension ProTUNMessage.Response.PcapUpdate: Equatable {}
extension ProTUNMessage.Response.PcapUpdate: Sendable {}
