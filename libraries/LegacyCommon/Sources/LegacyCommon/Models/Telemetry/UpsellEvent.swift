//
//  Created on 25.09.23.
//
//  Copyright (c) 2023 Proton AG
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

public struct UpsellEvent: TelemetryEvent, Encodable {
    public typealias VPNStatus = CommonTelemetryDimensions.VPNStatus
    public typealias CodingKeys = TelemetryKeys

    public let measurementGroup: String = "vpn.any.upsell"
    public let event: Event
    public let dimensions: Dimensions

    public init(event: Event, dimensions: Dimensions) {
        self.event = event
        self.dimensions = dimensions
    }

    public enum Event: String, Encodable {
        case display = "upsell_display"
        case upgradeAttempt = "upsell_upgrade_attempt"
        case success  = "upsell_success"
    }

    public struct Values: Encodable {
    }

    public var values: Values {
        return Values()
    }

    public enum ModalSource: String, Encodable {
        case secureCore = "secure_core"
        case netShield = "netshield"
        case countries
        case p2p
        case streaming
        case portForwarding = "port_forwarding"
        case profiles
        case vpnAccelerator = "vpn_accelerator"
        case splitTunneling = "split_tunneling"
        case customDns = "custom_dns"
        case allowLan = "allow_lan"
        case moderateNat = "moderate_nat"
        case safeMode = "safe_mode"
        case changeServer = "change_server"
        case promoOffer = "promo_offer"
        case downgrade
        case maxConnections = "max_connections"
    }

    public struct Dimensions: Encodable {
        public enum CodingKeys: String, CodingKey {
            case modalSource = "modal_source"
            case userPlan = "user_plan"
            case vpnStatus = "vpn_status"
            case userCountry = "user_country"
            case daysSinceAccountCreation = "days_since_account_creation"
            case upgradedUserPlan = "upgraded_user_plan"
            case reference = "reference"
        }

        public let modalSource: ModalSource
        public let userPlan: String
        public let vpnStatus: VPNStatus
        public let userCountry: String
        public let daysSinceAccountCreation: Int
        public let upgradedUserPlan: String?
        public let reference: String?

        var daysSinceAccountCreationEncodedValue: String {
            AccountCreationRangeBucket(intValue: daysSinceAccountCreation)?.rawValue ?? "n/a"
        }

        public func encode(to encoder: Encoder) throws {
            var container: KeyedEncodingContainer<UpsellEvent.Dimensions.CodingKeys> = encoder.container(keyedBy: UpsellEvent.Dimensions.CodingKeys.self)
            try container.encode(self.modalSource, forKey: .modalSource)
            try container.encode(self.userPlan, forKey: .userPlan)
            try container.encode(self.vpnStatus, forKey: .vpnStatus)
            try container.encode(self.userCountry, forKey: .userCountry)
            try container.encodeIfPresent(self.upgradedUserPlan, forKey: .upgradedUserPlan)
            try container.encodeIfPresent(self.reference, forKey: .reference)

            // Custom encoded values:
            try container.encode(self.daysSinceAccountCreationEncodedValue, forKey: .daysSinceAccountCreation)
        }
    }

    public enum AccountCreationRangeBucket: String, CaseIterable {
        case zero = "0"
        case one = "1-3"
        case four = "4-7"
        case eight = "8-14"
        case fifteen = ">14"

        var lowerBound: Int {
            switch self {
            case .zero:
                return 0
            case .one:
                return 1
            case .four:
                return 4
            case .eight:
                return 8
            case .fifteen:
                return 15
            }
        }

        init?(intValue: Int) {
            for value in Self.allCases.reversed() {
                if value.lowerBound <= intValue {
                    self = value
                    return
                }
            }
            return nil
        }
    }
}

