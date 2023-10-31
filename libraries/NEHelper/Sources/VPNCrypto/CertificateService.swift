//
//  Created on 31/10/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Dependencies

public struct CertificateService {
    var derRepresentation: (String) throws -> Data
    var publicKey: (Data) throws -> Data
}

extension CertificateService {
    /// Parses the textual representation of a PEM encoded certificate, according to the format defined by RFC-7468
    /// https://www.rfc-editor.org/rfc/rfc7468#section-5.1
    public func derRepresentation(ofPEMEncodedCertificate pem: String) throws -> Data {
        try derRepresentation(pem)
    }

    /// Returns the raw representation of the public key of a DER encoded certificate, without key metadata (e.g.
    /// algoorithm type and key length)
    public func publicKey(ofDEREncodedCertificate der: Data) throws -> Data {
        try publicKey(der)
    }
}

extension CertificateService: DependencyKey {
    public static let liveValue: CertificateService = CertificateService(
        derRepresentation: CertificateServiceImplementation.derRepresentation,
        publicKey: CertificateServiceImplementation.publicKey
    )

    #if DEBUG
    public static var testValue: CertificateService = liveValue

    public static func mock(derRepresentation: Data = Data(), publicKey: Data = Data()) -> CertificateService {
       return CertificateService(
            derRepresentation: { _ in derRepresentation},
            publicKey: { _ in publicKey }
        )
    }
    #endif
}

extension DependencyValues {
    public var certificateService: CertificateService {
        get { self[CertificateService.self] }
        set { self[CertificateService.self] = newValue }
    }
}

private enum CertificateServiceImplementation {
    public static func derRepresentation(ofPEMEncodedCertificate pem: String) throws -> Data {
        let regex = try! NSRegularExpression(pattern: "-----(BEGIN|END) CERTIFICATE-----")
        let range = NSRange(location: 0, length: pem.count)
        let pemWithoutHeaderAndFooter = regex.stringByReplacingMatches(in: pem, range: range, withTemplate: "")
        guard let der = Data(base64Encoded: pemWithoutHeaderAndFooter.replacingOccurrences(of: "\n", with: "")) else {
            throw CertificateCodingError.invalidBase64
        }
        return der
    }

    public static func publicKey(ofDEREncodedCertificate der: Data) throws -> Data {
        guard let secCertificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw CertificateCodingError.invalidBase64
        }
        guard let publicKey = SecCertificateCopyKey(secCertificate) else {
            throw CertificateCodingError.keyExtraction
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw CertificateCodingError.keyExport(internalError: error?.takeRetainedValue())
        }
        return publicKeyData as Data
    }

    enum CertificateCodingError: Error, CustomStringConvertible {
        var description: String {
            switch self {
            case .invalidBase64:
                return "Unable to decode base 64 data"
            case .certificateParsingFailure:
                return "Failed to parse certificate - is it a valid DER-encoded X.509 certificate?"
            case .keyExtraction:
                return "Failed to copy public key - possible encoding issue or unsupported algorithm"
            case .keyExport(let internalError):
                return "Failed to export public key with internal error: \(String(describing: internalError))"
            }
        }

        case invalidBase64
        case certificateParsingFailure
        case keyExtraction
        case keyExport(internalError: CFError?)
    }
}
