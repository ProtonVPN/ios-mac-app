//
//  Created on 28/11/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

#if DEBUG
    public extension FeatureFlags {
        static let allDisabled: Self = .init(
            smartReconnect: false,
            vpnAccelerator: false,
            netShield: false,
            netShieldStats: false,
            streamingServicesLogos: false,
            portForwarding: false,
            moderateNAT: false,
            pollNotificationAPI: false,
            serverRefresh: false,
            guestHoles: false,
            safeMode: false,
            promoCode: false,
            wireGuardTls: false,
            enforceDeprecatedProtocols: false,
            unsafeLanWarnings: false,
            mismatchedCertificateRecovery: false
        )
        static let allEnabled: Self = .init(
            smartReconnect: true,
            vpnAccelerator: true,
            netShield: true,
            netShieldStats: true,
            streamingServicesLogos: true,
            portForwarding: true,
            moderateNAT: true,
            pollNotificationAPI: true,
            serverRefresh: true,
            guestHoles: true,
            safeMode: true,
            promoCode: true,
            wireGuardTls: true,
            enforceDeprecatedProtocols: true,
            unsafeLanWarnings: true,
            mismatchedCertificateRecovery: true
        )

        static let wireGuardTlsDisabled: Self = .allEnabled
            .disabling(\.wireGuardTls)
    }
#endif
