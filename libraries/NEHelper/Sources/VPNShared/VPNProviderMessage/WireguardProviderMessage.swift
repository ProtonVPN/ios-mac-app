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

public enum WireguardProviderRequest: ProviderRequest {
    private enum MessageCode: UInt8 {
        // Standard messages
        case getRuntimeTunnelConfiguration = 0

        // Proton messages
        case flushLogsToFile = 101
        case setApiSelector = 102
        case refreshCertificate = 103

        case cancelRefreshOperations = 104
        case restartRefreshingCerts = 105

        case currentLogicalAndServerId = 106
    }

    private enum Keys: String {
        case selector
        case sessionCookie
    }

    /// Return the current WireGuard tunnel configuration string.
    case getRuntimeTunnelConfiguration
    /// Flush extension's logs to its log file.
    case flushLogsToFile
    /// Pass a selector representing an API session recently forked by the app.
    case setApiSelector(String, withSessionCookie: HTTPCookie?)
    /// Refresh the certificate used by the LocalAgent in the main app, and
    /// save it to the keychain before calling the completion.
    case refreshCertificate(features: VPNConnectionFeatures?)
    /// Cancel refresh operations and stop all timers. (Used on client's end to
    /// be able to manipulate objects in storage with guarantee that keychain won't
    /// be interfered with)
    case cancelRefreshes
    /// Restart certificate refreshes and reset timers. Used symmetrically with the above
    /// case, when the app has finished manipulating objects in storage and wants to
    /// let the extension continue with its normal refresh operations.
    case restartRefreshes
    /// Return current logical server and server IP ids. This is needed to to know if/when
    /// NE decides to reconnect to another server (for example after original goes into maintenance).
    case getCurrentLogicalAndServerId

    public var asData: Data {
        switch self {
        case .getRuntimeTunnelConfiguration:
            return datagram(.getRuntimeTunnelConfiguration)
        case .flushLogsToFile:
            return datagram(.flushLogsToFile)
        case let .setApiSelector(selector, sessionCookie):
            return encodeApiSelector(selector: selector, sessionCookie: sessionCookie)
        case .refreshCertificate(let features):
            let encoder = JSONEncoder()
            var featuresData: Data?
            if let features = features, let encodedFeatures = try? encoder.encode(features) {
                featuresData = encodedFeatures
            }
            return datagram(.refreshCertificate) + (featuresData ?? Data())
        case .cancelRefreshes:
            return datagram(.cancelRefreshOperations)
        case .restartRefreshes:
            return datagram(.restartRefreshingCerts)
        case .getCurrentLogicalAndServerId:
            return datagram(.currentLogicalAndServerId)
        }
    }

    public static func decode(data: Data) throws -> Self {
        guard let datagram = data.first else {
            throw ProviderMessageError.noDataReceived
        }

        guard let code = MessageCode(rawValue: datagram) else {
            throw ProviderMessageError.unknownRequest
        }

        switch code {
        case .getRuntimeTunnelConfiguration:
            return .getRuntimeTunnelConfiguration
        case .flushLogsToFile:
            return .flushLogsToFile
        case .setApiSelector:
            return try decodeApiSelector(data)
        case .refreshCertificate:
            var features: VPNConnectionFeatures?
            if let messageData = Self.messageData(rawData: data),
               let decodedFeatures = try? JSONDecoder().decode(VPNConnectionFeatures.self, from: messageData) {
                features = decodedFeatures
            }
            
            return .refreshCertificate(features: features)
        case .cancelRefreshOperations:
            return .cancelRefreshes
        case .restartRefreshingCerts:
            return .restartRefreshes
        case .currentLogicalAndServerId:
            return .getCurrentLogicalAndServerId
        }
    }

    private func encodeApiSelector(selector: String, sessionCookie: HTTPCookie?) -> Data {
        let cookieDict = sessionCookie?.asDict ?? [:]

        let dict: JSONDictionary = [
            Keys.selector.rawValue: selector as AnyObject,
            Keys.sessionCookie.rawValue: cookieDict as AnyObject
        ]

        let data = datagram(.setApiSelector) + ((try? JSONSerialization.data(withJSONObject: dict)) ?? Data())
        return data
    }

    private static func decodeApiSelector(_ data: Data) throws -> Self {
        guard let messageData = Self.messageData(rawData: data),
              let dict = (try? JSONSerialization.jsonObject(with: messageData)) as? JSONDictionary,
              let selector = dict[Keys.selector.rawValue] as? String,
              let sessionCookieDict = dict[Keys.sessionCookie.rawValue] as? JSONDictionary else {
            throw ProviderMessageError.decodingError
        }

        let sessionCookie = HTTPCookie.fromJSONDictionary(sessionCookieDict)
        return .setApiSelector(selector, withSessionCookie: sessionCookie)
    }

    private enum ResponseCode: UInt8 {
        case ok
        case sessionExpired
        case needKeyRegen
        case tooManyCertRequests
        case unrecoverableError
    }

    public enum Response: ProviderMessage {
        case ok(data: Data?)
        case errorSessionExpired
        case errorNeedKeyRegeneration
        case errorTooManyCertRequests(retryAfter: Int?)
        case error(message: String)

        private func datagram(_ code: ResponseCode) -> Data {
            Data([code.rawValue])
        }

        public var asData: Data {
            switch self {
            case .ok(let data):
                return datagram(.ok) + (data ?? Data())
            case .errorSessionExpired:
                return datagram(.sessionExpired)
            case .errorNeedKeyRegeneration:
                return datagram(.needKeyRegen)
            case .errorTooManyCertRequests(let retryAfter):
                var data = datagram(.tooManyCertRequests)
                if let retryAfter = retryAfter {
                    let intData = withUnsafeBytes(of: retryAfter) { bufPtr -> Data? in
                        guard let ptr = bufPtr.baseAddress else { return nil }
                        return Data(bytes: ptr, count: MemoryLayout<Int>.size)
                    }
                    data += intData ?? Data()
                }
                return data
            case .error(let message):
                return datagram(.unrecoverableError) + (message.data(using: .utf8) ?? Data())
            }
        }

        public static func decode(data: Data) throws -> WireguardProviderRequest.Response {
            guard let byte = data.first else {
                throw ProviderMessageError.decodingError
            }

            switch ResponseCode(rawValue: byte) {
            case .ok:
                var responseData: Data?
                if data.count > 1 {
                    responseData = data[1...]
                }
                return .ok(data: responseData)
            case .sessionExpired:
                return .errorSessionExpired
            case .needKeyRegen:
                return .errorNeedKeyRegeneration
            case .unrecoverableError:
                return .error(message: decodeMessage(data: data))
            case .tooManyCertRequests:
                return .errorTooManyCertRequests(retryAfter: decodeInteger(Int.self, data: data))
            case nil:
                throw ProviderMessageError.unknownResponse
            }
        }
    }

    private static func decodeMessage(data: Data) -> String {
        guard data.count > 1 else {
            return ""
        }
        return String(data: data[1...], encoding: .utf8) ?? ""
    }

    private static func decodeInteger<N: BinaryInteger>(_ type: N.Type, data: Data) -> N? {
        let width = MemoryLayout<N>.size
        guard data.count == 1 + width else { return nil }

        return data[1...].withUnsafeBytes { bufPtr -> N? in
            guard let ptr = bufPtr.baseAddress else { return nil }
            return ptr.bindMemory(to: N.self, capacity: 1).pointee
        }
    }

    // MARK: - Private

    private func datagram(_ code: MessageCode) -> Data {
        Data([code.rawValue])
    }

    /// Returns all data after the "datagram" value.
    private static func messageData(rawData: Data) -> Data? {
        guard rawData.count > 1 else {
            return nil
        }
        return rawData[1...]
    }
}

private extension HTTPCookiePropertyKey {
    var hasDateRepresentation: Bool {
        return rawValue.lowercased() == "created" || rawValue.lowercased() == "expires"
    }
}

private extension HTTPCookie {
    var asDict: JSONDictionary? {
        guard let properties = properties else { return nil }

        let dict: JSONDictionary = properties.reduce(into: [:], { partialResult, kvPair in
            if kvPair.key.hasDateRepresentation, let date = kvPair.value as? Date {
                partialResult[kvPair.key.rawValue] = Int(date.timeIntervalSince1970) as AnyObject
            } else {
                partialResult[kvPair.key.rawValue] = kvPair.value as AnyObject
            }
        })

        return dict
    }

    static func fromJSONDictionary(_ dict: JSONDictionary) -> HTTPCookie? {
        let cookieProperties: [HTTPCookiePropertyKey: Any] = dict.reduce(into: [:]) { partialResult, kvPair in
            let propertyKey = HTTPCookiePropertyKey(kvPair.key)
            if propertyKey.hasDateRepresentation, let value = kvPair.value as? Int {
                partialResult[propertyKey] = Date(timeIntervalSince1970: TimeInterval(value))
            } else {
                partialResult[propertyKey] = kvPair.value
            }
        }

        return HTTPCookie(properties: cookieProperties)
    }
}

extension Data {
    var jsonDictionary: JSONDictionary? {
        return (try? JSONSerialization.jsonObject(with: self, options: .mutableContainers)) as? JSONDictionary
    }
}
