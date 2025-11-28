//
//  Created on 02/11/2023.
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

#if os(iOS)
    import Foundation
    import XCTest

    import Dependencies

    @testable import CommonNetworking
    import VPNShared

    class VPNAuthenticationRemoteClientTests: XCTestCase {
        let expectationTimeout = 1.0

        func testCertificateMismatchNotTestedWhenFeatureFlagIsOff() async { // swiftlint:disable:this function_body_length
            // Populate auth storage with any random certificate
            var authStorage = VpnAuthenticationStorage.testStorage(keys: .mock(publicKey: "BobsPKey".decodeBase64()), certificate: .init(certificate: "abc", validUntil: Date(), refreshTime: Date()))
            let tunnelMock = WireguardProviderMessageSenderMock()

            let certLoad = oneTimeExpectation(description: "Certificate should be requested after the old one is deleted")

            authStorage.deleteCertificate = { XCTFail("We shouldn't delete our stored certificate if the FF is off") }

            tunnelMock.wireguardRequestSent = { _ in
                XCTFail("We shouldn't talk to the extension because we have a certificate in storage and we shouldn't check its validity")
                return .success(.ok(data: nil)) // doesn't really matter what we send back, the test failed already
            }

            withDependencies {
                $0.vpnAuthenticationStorage = authStorage
                $0.date = .constant(Date())
                $0.featureFlagProvider = .constant(flags: .allEnabled.disabling(\.mismatchedCertificateRecovery))
                $0.certificateCryptoService = .mock(
                    publicKey: { _ in
                        XCTFail("We should not try to calculate the certificate's public key when FF is false")
                        return Data()
                    }
                )
            } operation: {
                let sut = VpnAuthenticationRemoteClient()
                sut.setConnectionProvider(provider: tunnelMock)

                sut.loadAuthenticationData(features: nil) { result in
                    guard case .success = result else {
                        XCTFail("We shouldn't fail when refreshing our certificate")
                        return
                    }
                    certLoad.fulfill()
                }
            }

            await fulfillment(of: [certLoad], timeout: expectationTimeout)
        }

        func testCertificateIsDeletedAndRefreshedWhenMismatchedCertificateStoredInKeychain() async { // swiftlint:disable:this function_body_length
            // Populate auth storage with any random certificate
            var authStorage = VpnAuthenticationStorage.testStorage(keys: .mock(publicKey: "BobsPKey".decodeBase64()), certificate: .init(certificate: "abc", validUntil: Date(), refreshTime: Date()))

            let tunnelMock = WireguardProviderMessageSenderMock()

            let expectations = (
                certDeletion: oneTimeExpectation(description: "Mismatched certificate should be deleted"),
                certRefresh: oneTimeExpectation(description: "Mismatched certificate should be refreshed"),
                certLoad: oneTimeExpectation(description: "Certificate should be requested after the old one is deleted")
            )

            authStorage.deleteCertificate = { expectations.certDeletion.fulfill() }

            tunnelMock.wireguardRequestSent = { request in
                guard case .refreshCertificate = request else {
                    XCTFail("Incorrect request received")
                    return .success(.ok(data: nil)) // doesn't really matter what we send back, the test failed already
                }

                // Let's insert some random certificate into storage and later pretend its public key is fine this time
                authStorage.storeCertificate(.init(certificate: "abc", validUntil: Date(), refreshTime: Date()))
                expectations.certRefresh.fulfill()
                return .success(.ok(data: nil))
            }

            withDependencies {
                $0.date = .constant(Date())
                $0.featureFlagProvider = .constant(flags: .allEnabled)
                $0.certificateCryptoService = .mock(publicKey: { _ in "EvesPKey".decodeBase64() }) // Not BobsPublicKey
                $0.vpnAuthenticationStorage = authStorage
            } operation: {
                let sut = VpnAuthenticationRemoteClient()
                sut.setConnectionProvider(provider: tunnelMock)

                // Make sure we've set up the test case correctly
                XCTAssertNotEqual(
                    try! authStorage.getStoredCertificate()!.getPublicKey(),
                    Data(authStorage.getStoredKeys()!.publicKey.rawRepresentation),
                    "Stored certificate's public key should be different from our stored public key"
                )
                sut.loadAuthenticationData(features: nil) { result in
                    guard case .success = result else {
                        XCTFail("We shouldn't fail when refreshing our certificate")
                        return
                    }
                    expectations.certLoad.fulfill()
                }
            }

            await fulfillment(
                of: [expectations.certDeletion, expectations.certRefresh, expectations.certLoad],
                timeout: expectationTimeout,
                enforceOrder: true
            )
        }

        func testCertificateIsNotRefreshedWhenValidCertificateStoredInKeychain() async { // swiftlint:disable:this function_body_length
            // Populate auth storage with a certificate generated against a public key different to our current one
            var authStorage = VpnAuthenticationStorage.testStorage(keys: .mock(publicKey: "BobsPkey".decodeBase64()), certificate: .init(certificate: "xyz", validUntil: Date(), refreshTime: Date()))
            let tunnelMock = WireguardProviderMessageSenderMock()

            let certLoad = oneTimeExpectation(description: "Certificate should be loaded from storage")

            tunnelMock.wireguardRequestSent = { _ in
                XCTFail("We shouldn't talk to the extension if our certificate doesn't need refreshing")
                return .success(.ok(data: nil)) // doesn't really matter what we send back, the test failed already
            }

            authStorage.deleteCertificate = { XCTFail("We shouldn't delete valid certificates") }

            withDependencies {
                $0.vpnAuthenticationStorage = authStorage
                $0.date = .constant(Date())
                $0.featureFlagProvider = .constant(flags: .allEnabled)
                $0.certificateCryptoService = .mock(publicKey: { _ in "BobsPkey".decodeBase64() }) // Matching public key
            } operation: {
                let sut = VpnAuthenticationRemoteClient()
                sut.setConnectionProvider(provider: tunnelMock)

                // Make sure we've set up the test case correctly
                XCTAssertEqual(
                    try! authStorage.getStoredCertificate()!.getPublicKey(),
                    Data(authStorage.getStoredKeys()!.publicKey.rawRepresentation),
                    "Stored certificate's public key should match our public key"
                )
                sut.loadAuthenticationData(features: nil) { result in
                    guard case .success = result else {
                        XCTFail("We shouldn't fail when refreshing our certificate")
                        return
                    }
                    certLoad.fulfill()
                }
            }

            await fulfillment(
                of: [certLoad],
                timeout: expectationTimeout,
                enforceOrder: true
            )
        }

        func testCertificateIsRefreshedWhenNoCertificateStoredInKeychain() async { // swiftlint:disable:this function_body_length
            // Populate auth storage with a certificate generated against a public key different to our current one
            var authStorage = VpnAuthenticationStorage.testStorage(keys: .mock(publicKey: "BobsPKey".decodeBase64()))
            let tunnelMock = WireguardProviderMessageSenderMock()

            let expectations = (
                certRefresh: oneTimeExpectation(description: "Certificate should be refreshed"),
                certLoad: oneTimeExpectation(description: "Certificate should be successfully loaded after it's refreshed")
            )

            tunnelMock.wireguardRequestSent = { request in
                guard case .refreshCertificate = request else {
                    XCTFail("Incorrect request received")
                    return .success(.ok(data: nil)) // doesn't really matter what we send back, the test failed already
                }

                // Let's insert some random certificate into storage and later pretend its public key is fine this time
                authStorage.storeCertificate(.init(certificate: "abc", validUntil: Date(), refreshTime: Date()))
                expectations.certRefresh.fulfill()
                return .success(.ok(data: nil))
            }

            withDependencies {
                $0.vpnAuthenticationStorage = authStorage
                $0.date = .constant(Date())
                $0.featureFlagProvider = .constant(flags: .allEnabled)
            } operation: {
                let sut = VpnAuthenticationRemoteClient()
                sut.setConnectionProvider(provider: tunnelMock)

                // Make sure we've set up the test case correctly
                sut.loadAuthenticationData(features: nil) { result in
                    guard case .success = result else {
                        XCTFail("We shouldn't fail when refreshing our certificate")
                        return
                    }
                    expectations.certLoad.fulfill()
                }
            }

            await fulfillment(
                of: [expectations.certRefresh, expectations.certLoad],
                timeout: expectationTimeout,
                enforceOrder: true
            )
        }

        private func oneTimeExpectation(description: String) -> XCTestExpectation {
            let expectation = XCTestExpectation(description: description)
            expectation.expectedFulfillmentCount = 1
            expectation.assertForOverFulfill = true
            return expectation
        }
    }
#endif
