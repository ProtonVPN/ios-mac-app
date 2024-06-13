//
//  Created on 13/06/2024.
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

public struct VPNAuthenticationData {
    public let clientKey: PrivateKey
    public let clientCertificate: String

    public init(clientKey: PrivateKey, clientCertificate: String) {
        self.clientKey = clientKey
        self.clientCertificate = clientCertificate
    }
}

#if DEBUG
// Can be moved to a separate target if there are more things we'd like mocks of in the future
extension VPNAuthenticationData {
    public static let empty = VPNAuthenticationData(
        clientKey: .init(rawRepresentation: [], derRepresentation: "", base64X25519Representation: ""),
        clientCertificate: ""
    )
}
#endif
