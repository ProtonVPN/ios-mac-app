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
import struct Domain.VPNConnectionFeatures
import ConnectionFoundations

package struct CertificateAuthentication: DependencyKey {
    package var loadAuthenticationData: (VPNConnectionFeatures?) async throws -> VPNAuthenticationData

    package init(loadAuthenticationData: @escaping (VPNConnectionFeatures?) async throws -> VPNAuthenticationData) {
        self.loadAuthenticationData = loadAuthenticationData
    }

    package static let liveValue: CertificateAuthentication = {
        // Stubbed out for now while Certificate Authentication is under development
        return .init(loadAuthenticationData: { _ in .empty })
    }()
}

extension DependencyValues {
    package var certificateAuthentication: CertificateAuthentication {
        get { self[CertificateAuthentication.self] }
        set { self[CertificateAuthentication.self] = newValue }
    }
}
