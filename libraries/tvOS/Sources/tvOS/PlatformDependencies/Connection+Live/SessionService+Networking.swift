//
//  Created on 21/06/2024.
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
import CertificateAuthentication
import CommonNetworking

extension SessionService: DependencyKey {
    public static let liveValue: SessionService = {
        @Dependency(\.networking) var networking

        return SessionService(
            selector: {
                // TODO: Uncomment real implementation once recursive forking is supported
                return "abcd" // For testing, hardcode your main selector (fetched during signin) here

                // let clientId = "Wireguard-tvOS"
                // let forkRequest = ForkSessionRequest(useCase: .getSelector(clientId: clientId, independent: false))
                // let response: ForkSessionResponse = try await networking.perform(request: forkRequest)
                // return response.selector
            },
            sessionCookie: { networking.sessionCookie }
        )
    }()
}

