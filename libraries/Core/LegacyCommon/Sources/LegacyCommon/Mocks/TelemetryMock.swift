//
//  Created on 19/12/2022.
//
//  Copyright (c) 2022 Proton AG
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

#if DEBUG
    import Foundation

    public extension ConnectionEvent {
        static let connectionMock1 = ConnectionEvent(
            event: .vpnConnection(timeToConnection: 123),
            dimensions: .connectionSuccessMock1
        )
        static let disconnectionMock1 = ConnectionEvent(
            event: .vpnDisconnection(sessionLength: 123),
            dimensions: .disconnectionSuccessMock1
        )
    }

    public extension ConnectionEvent.Values {
        static let connectionMock1 = ConnectionEvent.Values(timeToConnection: 123)
        static let disconnectionMock1 = ConnectionEvent.Values(sessionLength: 123)
    }

    public extension ConnectionDimensions {
        static let connectionSuccessMock1 = ConnectionDimensions(
            outcome: .success,
            userTier: .free,
            vpnStatus: .on,
            vpnTrigger: .country,
            networkType: .wifi,
            serverFeatures: .zero,
            vpnCountry: "CHE",
            userCountry: "FRA",
            protocol: .wireGuard(.tls),
            server: "#IT1",
            port: "1234",
            isp: "Play",
            isServerFree: false
        )

        static let disconnectionSuccessMock1 = ConnectionDimensions(
            outcome: .success,
            userTier: .paid,
            vpnStatus: .off,
            vpnTrigger: .server,
            networkType: .mobile,
            serverFeatures: [.p2p, .tor],
            vpnCountry: "POL",
            userCountry: "BEL",
            protocol: .openVpn(.udp),
            server: "#PL1",
            port: "5678",
            isp: "Netia",
            isServerFree: true
        )
    }

    extension UpsellEvent {
        static let upsellEventDisplayMock: Self = .init(event: .display, dimensions: .upsellEventDimensionsMock1)
        static let upsellEventUpgradeMock: Self = .init(event: .upgradeAttempt, dimensions: .upsellEventDimensionsMock1)
        static let upsellEventSuccessMock: Self = .init(event: .success, dimensions: .upsellEventDimensionsMock2)
    }

    public extension UpsellEvent.Dimensions {
        static let upsellEventDimensionsMock1: Self = .init(
            modalSource: .changeServer,
            userPlan: "free",
            userTier: .free,
            vpnStatus: .off,
            userCountry: "ZZ",
            daysSinceAccountCreation: 12,
            upgradedUserPlan: nil,
            reference: nil,
            flowType: nil,
            isCredentiallessEnabled: "no"
        )

        static let upsellEventDimensionsMock2: Self = .init(
            modalSource: .changeServer,
            userPlan: "free",
            userTier: .paid,
            vpnStatus: .off,
            userCountry: "ZZ",
            daysSinceAccountCreation: 12,
            upgradedUserPlan: "plus",
            reference: nil,
            flowType: nil,
            isCredentiallessEnabled: "no"
        )
    }
#endif
