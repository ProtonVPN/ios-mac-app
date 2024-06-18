//
//  Created on 07/06/2024.
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
import Dependencies
import ExtensionIPC
import ConnectionFoundations

package struct CertificateAuthentication: DependencyKey {
    // We might not need to set the sender explicitly
    // Maybe we can just use the ExtensionManager dependency to send the message directly
    package var setMessageSender: (ProviderMessageSender?) -> Void
    package var loadAuthenticationData: () async throws -> VPNAuthenticationData

    package init(
        setMessageSender: @escaping (ProviderMessageSender?) -> Void,
        loadAuthenticationData: @escaping () async throws -> VPNAuthenticationData
    ) {
        self.setMessageSender = setMessageSender
        self.loadAuthenticationData = loadAuthenticationData
    }

    // TODO: Implement this once ExtensionAPIService has been integrated
    package static let liveValue = CertificateAuthentication(
        setMessageSender: unimplemented(),
        loadAuthenticationData: unimplemented()
    )
}

extension DependencyValues {
    package var certificateAuthentication: CertificateAuthentication {
        get { self[CertificateAuthentication.self] }
        set { self[CertificateAuthentication.self] = newValue }
    }
}
