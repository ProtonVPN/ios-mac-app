//
//  Created on 03/12/2024.
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

import CertificateAuthentication
import CommonNetworking
import Dependencies

extension CertificateAuthentication.SessionService: DependencyKey {
    public static let liveValue: CertificateAuthentication.SessionService = {
        @Dependency(\.networking) var networking
        @Dependency(\.appInfo) var appInfo

        return CertificateAuthentication.SessionService(
            selector: {
                let clientId = appInfo.clientId(forContext: .wireGuardExtension)
                let forkRequest = ForkSessionRequest(useCase: .getSelector(clientId: clientId, independent: false))
                let response: ForkSessionResponse = try await networking.perform(request: forkRequest)
                return response.selector
            },
            sessionCookie: { networking.sessionCookie }
        )
    }()
}
