//
//  Created on 14/06/2024.
//
//  Copyright (c) 2024 Proton AG
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
import struct Domain.VPNConnectionFeatures
import struct VPNShared.VpnCertificate

public struct FullAuthenticationData: Equatable, Sendable {
    public let keys: VPNKeys
    public let certificate: VpnCertificate
    public let features: VPNConnectionFeatures?

    public init(keys: VPNKeys, certificate: VpnCertificate, features: VPNConnectionFeatures?) {
        self.keys = keys
        self.certificate = certificate
        self.features = features
    }

    /// Returns a subset of data necessary to authenticate a LocalAgent connection
    public var authenticationData: VPNAuthenticationData {
        return VPNAuthenticationData(
            clientKey: keys.privateKey,
            clientCertificate: certificate.certificate
        )
    }
}
