//
//  Created on 18/12/2024.
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

#if os(tvOS)
    import Domain
    import Dependencies
    import CoreConnection

    extension ConnectionFeatureProvider: DependencyKey {
        public static let liveValue: ConnectionFeatureProvider = .init(
            connectionFeatures: { .defaultFeatures },
            setConnectionFeatures: { _ in log.assertionFailure("Nothing to do on tvOS yet") },
            tunnelFeatures: { .init() },
            connectionProtocol: { .vpnProtocol(.wireGuard(.udp)) }
        )
    }

    extension VPNConnectionFeatures {
        static let defaultFeatures: VPNConnectionFeatures = {
            VPNConnectionFeatures(
                netshield: .level1,
                vpnAccelerator: true,
                bouncing: nil, // This is set to the target server's `label` property during connection
                natType: .moderateNAT,
                safeMode: false
            )
        }()
    }
#endif
