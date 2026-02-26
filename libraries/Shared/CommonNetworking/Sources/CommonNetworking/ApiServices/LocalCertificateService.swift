//
//  Created on 14/01/2026 by Chris Janusiewicz.
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

import Dependencies
import Domain
import Foundation
import VPNShared

/// Temporary certificate refresh service, for use in ProTUN until the rust certificate refresh library is ready
public struct LocalCertificateService: DependencyKey {
    public private(set) var refreshCertificate: (_ publicKey: PublicKey, _ features: VPNConnectionFeatures) async throws -> Void

    public static let liveValue = LocalCertificateService(refreshCertificate: { publicKey, features in
        @Dependency(\.networking) var networking
        @Dependency(\.vpnAuthenticationStorage) var storage
        log.debug("Refreshing VPN certificate within the app", category: .userCert)

        let request = CertificateRequest(publicKey: publicKey, features: features)
        let certDict = try await networking.perform(request: request)
        log.debug("Certificate fetched", category: .userCert)
        try storage.storeCertificateWithFeatures(.init(certificate: .init(dict: certDict), features: features))
        log.debug("Certificate stored", category: .userCert)
    })
}

public extension DependencyValues {
    var localCertificateService: LocalCertificateService {
        get { self[LocalCertificateService.self] }
        set { self[LocalCertificateService.self] = newValue }
    }
}
