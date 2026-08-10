//
//  Created on 17/02/2026.
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

import struct Foundation.URL
import struct Foundation.UUID
import IPCErgonomics

public enum ProTUNMessage {
    public struct Request: Codable {
        public let version: Version
        public let payload: Payload

        public init(version: Version = .current, payload: Payload) {
            self.version = version
            self.payload = payload
        }
    }

    public struct Response: Codable {
        public let version: Version
        public let payload: Payload

        public init(version: Version = .current, payload: Payload) {
            self.version = version
            self.payload = payload
        }
    }
}

public extension ProTUNMessage.Request {
    enum Payload: Sendable, Codable, Equatable {
        case flushLogsToFile
        case retrieveLogsArchive
        case pcapRequest(PcapRequest)
        case pushForkInfo(selector: String, cookieName: String, cookieValue: String)
        case updateConfiguration(ConnectionUpdate)
        case ack(errorId: UUID)
        #if DEBUG
            case ping
        #endif
    }
}

public extension ProTUNMessage.Response {
    enum Payload: Sendable, Codable, Equatable {
        case ack
        case logs(CodableResult<URL, Error>)
        case error(GenericError)
        #if DEBUG
            case pong
        #endif
    }
}

public extension ProTUNMessage {
    enum Version: UInt8, Codable {
        public static let current: Self = .v1

        case v1 = 1
    }
}

extension ProTUNMessage: Sendable {}
extension ProTUNMessage.Request: Sendable {}
extension ProTUNMessage.Response: Sendable {}

extension ProTUNMessage.Version: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension ProTUNMessage.Version: Sendable {}

public extension ProTUNMessage.Response {
    struct Error: Swift.Error, Codable {
        public let failureReason: String

        public init(failureReason: String) {
            self.failureReason = failureReason
        }
    }

    enum GenericError: Codable {
        case unsupported(incoming: ProTUNMessage.Version, supported: ProTUNMessage.Version, reason: String)
        case other(reason: String)
    }

    static func genericError(_ reason: String) -> Self {
        .init(payload: .error(.other(reason: reason)))
    }
}

extension ProTUNMessage.Request.Payload: CustomStringConvertible {
    public var description: String {
        switch self {
        #if DEBUG
            case .ping: "ping"
        #endif
        case .flushLogsToFile: "flushLogsToFile"
        case .retrieveLogsArchive: "retrieveLogsArchive"
        case let .pcapRequest(request): "pcapRequest(\(request))"
        case .pushForkInfo: "pushForkInfo"
        case .updateConfiguration: "updateConfiguration"
        case let .ack(errorId): "ack(\(errorId))"
        }
    }
}

extension ProTUNMessage.Request.PcapRequest: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .start(fileURL): "start(\(fileURL.lastPathComponent))"
        case .stop: "stop"
        }
    }
}

extension ProTUNMessage.Response.Error: Sendable {}
extension ProTUNMessage.Response.Error: Equatable {}
extension ProTUNMessage.Response.GenericError: Sendable {}
extension ProTUNMessage.Response.GenericError: Equatable {}
