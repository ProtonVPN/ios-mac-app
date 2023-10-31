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

#if os(iOS) // CertificateServiceImplementation is only available on iOS because of shortcomings in the Security framework

import Foundation
import XCTest
@testable import VPNCrypto

private let certPEM = """
-----BEGIN CERTIFICATE-----
MIIBkzCCAUWgAwIBAgIUHyiBzY3Vr+lbiFMpH1M+dW8xluQwBQYDK2VwMD8xCzAJ
BgNVBAYTAkNIMRMwEQYDVQQIDApTb21lLVN0YXRlMRswGQYDVQQKDBJCb2IncyBD
ZXJ0aWZpY2F0ZXMwHhcNMjMxMDMxMTQzNjExWhcNMzMxMDI4MTQzNjExWjA/MQsw
CQYDVQQGEwJDSDETMBEGA1UECAwKU29tZS1TdGF0ZTEbMBkGA1UECgwSQm9iJ3Mg
Q2VydGlmaWNhdGVzMCowBQYDK2VwAyEA2kdfsHBG1NxeKzOxbu4os8ePhLpudcG7
+DbPuJg4BKWjUzBRMB0GA1UdDgQWBBRJrVcN9w7kz2c8Xzm5NPvvyxgaBTAfBgNV
HSMEGDAWgBRJrVcN9w7kz2c8Xzm5NPvvyxgaBTAPBgNVHRMBAf8EBTADAQH/MAUG
AytlcANBAFziCR0x2WGFCzYUikvN4Flm2iIsOei5KWLT20BWDOOv+Rt2UMTB0ob+
sN3OAU7x+DQwJXFZQLzvop8oF8bygQk=
-----END CERTIFICATE-----
"""

let expectedPubKeyBase64 = "2kdfsHBG1NxeKzOxbu4os8ePhLpudcG7+DbPuJg4BKU=" // key used when generating certPEM
let incorrectPubKeyBase64 = "/qg17z83LiIoykVRZu6/NAJC/B1tZXDZlLJjSk2/yz8=" // random unrelated public key

final class CertificateCryptoTests: XCTestCase {
    func testCertificateDecodedWithCorrectPublicKey() throws {
        let certificateDER = try CertificateServiceImplementation.derRepresentation(ofPEMEncodedCertificate: certPEM)
        let certificatePublicKey = try CertificateServiceImplementation.publicKey(ofDEREncodedCertificate: certificateDER)

        XCTAssertEqual(certificatePublicKey, Data(base64Encoded: expectedPubKeyBase64), "Certificate public key mismatch")
        XCTAssertNotEqual(certificatePublicKey, Data(base64Encoded: incorrectPubKeyBase64), "Should not match unrelated public key - false positive")
    }
}

#endif
