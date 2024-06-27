//
//  VpnCertificate.swift
//  vpncore - Created on 15.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import Dependencies

import Domain
import Ergonomics
import VPNCrypto

public struct VpnCertificate: Sendable, Equatable {
    public let certificate: String // PEM representation
    public let validUntil: Date
    public let refreshTime: Date

    public var isExpired: Bool {
        return Date() > validUntil
    }

    public var shouldBeRefreshed: Bool {
        return Date() > refreshTime
    }

    enum CodingKeys: String, CodingKey {
        case certificate = "Certificate"
        case validUntil = "ExpirationTime"
        case refreshTime = "RefreshTime"
    }

    public init(certificate: String, validUntil: Date, refreshTime: Date) {
        self.certificate = certificate
        self.validUntil = validUntil
        self.refreshTime = refreshTime

    }

    #if os(iOS)
    // Not implemented on MacOS, see CertificateCryptoService
    public func getPublicKey() throws -> Data {
        @Dependency(\.certificateCryptoService) var crypto
        let derRepresentation = try crypto.derRepresentation(ofPEMEncodedCertificate: certificate)
        return try crypto.publicKey(ofDEREncodedCertificate: derRepresentation)
    }
    #endif
}

public extension VpnCertificate {
    init(dict: JSONDictionary) throws {
        self.init(
            certificate: try dict.stringOrThrow(key: "Certificate"),
            validUntil: try dict.unixTimestampOrThrow(key: "ExpirationTime"),
            refreshTime: try dict.unixTimestampOrThrow(key: "RefreshTime")
        )
    }
}

extension VpnCertificate: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            certificate: try container.decode(String.self, forKey: .certificate),
            validUntil: try container.decode(Date.self, forKey: .validUntil),
            refreshTime: try container.decode(Date.self, forKey: .refreshTime)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(certificate, forKey: .certificate)
        try container.encode(validUntil, forKey: .validUntil)
        try container.encode(refreshTime, forKey: .refreshTime)
    }

}

extension VpnCertificate: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        var properties = [
            "certificateFingerprint: '\(certificate.fingerprint)'",
            "validUntil: '\(validUntil)'",
            "refreshTime: '\(refreshTime)'"
        ]
        #if os(iOS) && DEBUG
        do {
            let publicKey = try getPublicKey()
            // On release builds, let's avoid the costly process of parsing the certificate every time we want to log it
            properties.append(contentsOf: [
                "certificatePublicKeyFingerprint: '\(publicKey.fingerprint)'",
                "certificatePublicKey: '\(publicKey.base64EncodedString())'"
            ])
        } catch {
            properties.append("certificateError: \(error)")
        }
        #endif

        return "VPNCertificate(\(properties.joined(separator: ", ")))"
    }
    
    public var debugDescription: String { return description }
}

public struct VpnCertificateWithFeatures {
    public let certificate: VpnCertificate
    public let features: VPNConnectionFeatures?

    public init(certificate: VpnCertificate, features: VPNConnectionFeatures?) {
        self.certificate = certificate
        self.features = features
    }
}
