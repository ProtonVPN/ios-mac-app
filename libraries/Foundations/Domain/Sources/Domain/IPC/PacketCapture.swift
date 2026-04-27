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
import Sharing

public enum PacketCaptureInterruptionReason: UInt64 {
    case unknown
    case connectionTerminated
    case explicitStop
    case timerHit
    case storageLimitHit
}

extension PacketCaptureInterruptionReason: Codable {}
extension PacketCaptureInterruptionReason: Sendable {}

public enum CaptureSession: Equatable, Codable, Sendable {
    public static let storageKey: String = "PcapSession"

    case noSession
    case sessionStarted(urlWithDate: URLWithDate)
    case sessionEnded(urlWithSize: URLWithSize, reason: PacketCaptureInterruptionReason)
}

public extension SharedKey where Self == AppStorageKey<CaptureSession>.Default {
    static var captureSession: Self {
        Self[.appStorage(CaptureSession.storageKey), default: .noSession]
    }
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
        case captureFinished(CodableResult<URLWithSize, Error>)
    }
}

public struct URLWithSize: Codable, Equatable, Sendable {
    public let url: URL
    public let size: Int64
    public init(url: URL, size: Int64) {
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

extension ProTUNMessage.Response.PcapUpdate: Equatable {}
extension ProTUNMessage.Response.PcapUpdate: Sendable {}
