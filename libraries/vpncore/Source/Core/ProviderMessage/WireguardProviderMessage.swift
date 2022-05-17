//
//  Created on 2022-05-17.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

enum WireguardProviderRequest: ProviderRequest {
    private enum MessageCode: UInt8 {
        // Standard messages
        case getRuntimeTunnelConfiguration = 0

        // Proton messages
        case flushLogsToFile = 101
        case setApiSelector = 102
    }

    /// Return the current WireGuard tunnel configuration string.
    case getRuntimeTunnelConfiguration
    /// Flush extension's logs to its log file.
    case flushLogsToFile
    /// Pass a selector representing an API session recently forked by the app.
    case setApiSelector(String)

    public var asData: Data {
        switch self {
        case .getRuntimeTunnelConfiguration:
            return datagram(.getRuntimeTunnelConfiguration)
        case .flushLogsToFile:
            return datagram(.flushLogsToFile)
        case .setApiSelector(let selector):
            return datagram(.setApiSelector) + (selector.data(using: .utf8) ?? Data())
        }
    }

    static func decode(data: Data) throws -> Self {
        guard let datagram = data.first else {
            throw ProviderMessageError.noDataReceived
        }

        guard let code = MessageCode(rawValue: datagram) else {
            throw ProviderMessageError.unknownMessage
        }

        switch code {
        case .getRuntimeTunnelConfiguration:
            return .getRuntimeTunnelConfiguration
        case .flushLogsToFile:
            return .flushLogsToFile
        case .setApiSelector:
            guard let message = Self.messageData(rawData: data),
                  let selector = String(data: message, encoding: .utf8) else {
                throw ProviderMessageError.decodingError
            }
            return .setApiSelector(selector)
        }
    }

    public enum Response: ProviderMessage {
        case ok(data: Data?)
        case error(message: String)

        public var asData: Data {
            switch self {
            case .ok(let data):
                return Data([0]) + (data ?? Data())
            case .error(let message):
                return Data([255]) + (message.data(using: .utf8) ?? Data())
            }
        }

        public static func decode(data: Data) throws -> WireguardProviderRequest.Response {
            if data.first == 0 {
                var responseData: Data?
                if data.count > 1 {
                    responseData = data[1...]
                }
                return .ok(data: responseData)
            } else if data.first == 255 {
                let message: String
                if data.count > 1 {
                    message = String(data: data[1...], encoding: .utf8) ?? ""
                } else {
                    message = ""
                }
                return .error(message: message)
            } else {
                throw ProviderMessageError.decodingError
            }
        }
    }

    // MARK: - Private

    private func datagram(_ code: MessageCode) -> Data {
        Data([code.rawValue])
    }

    private static func messageData(rawData: Data) -> Data? {
        guard rawData.count > 1 else {
            return nil
        }
        return rawData[1...]
    }
}
