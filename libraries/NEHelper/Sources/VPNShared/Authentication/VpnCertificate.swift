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

public struct VpnCertificate {
    public let certificate: String // PEM representation
    public let validUntil: Date
    public let refreshTime: Date

    // Derived properties, not present in payload
    public let derRepresentation: Data?
    public let publicKey: Data?

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
        if let der = CertificateEncoding.derRepresentation(ofPEMEncodedCertificate: certificate) {
            self.derRepresentation = der
            self.publicKey = CertificateEncoding.publicKey(ofDEREncodedCertificate: der)
        } else {
            log.error("Failed to derive a DER representation for this certificate", category: .userCert)
            self.derRepresentation = nil
            self.publicKey = nil
        }
    }
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
        let properties = [
            "publicKeyFingerprint: \(publicKey?.fingerprint ?? "nil")",
            "validUntil: \(validUntil)",
            "refreshTime: \(refreshTime)"
        ]

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


enum CertificateEncoding {
    static func derRepresentation(ofPEMEncodedCertificate pem: String) -> Data? {
        let regex = try! NSRegularExpression(pattern: "-----(BEGIN|END) CERTIFICATE-----")
        let range = NSRange(location: 0, length: pem.count)
        let pemWithoutHeaderAndFooter = regex.stringByReplacingMatches(in: pem, range: range, withTemplate: "")
        return Data(base64Encoded: pemWithoutHeaderAndFooter.replacingOccurrences(of: "\n", with: ""))
    }

    static func publicKey(ofDEREncodedCertificate der: Data) -> Data? {
        guard let secCertificate = SecCertificateCreateWithData(nil, der as CFData) else {
            log.error("Failed to parse certificate - is it a valid DER-encoded X.509 certificate?", category: .userCert)
            return nil
        }
        guard let publicKey = SecCertificateCopyKey(secCertificate) else {
            log.error("Failed to copy public key - possible encoding issue or unsupported algorithm", category: .userCert)
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            log.error("Failed to export public key", category: .userCert, metadata: ["error": "\(String(describing: error))"])
            return nil
        }
        return publicKeyData as Data
    }
}
