//
//  Created on 08/01/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import Foundation
import Localization
import ProtonCoreUIFoundations
import Strings
import Theme
import UIKit
import VPNAppCore
import VPNShared

@Reducer
public struct CityFeature {
    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        let cityName: String
        let countryCode: String
        var servers: IdentifiedArrayOf<ServerItemFeature.State>

        public var id: String { "\(cityName)-\(countryCode)" }

        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.userTier) var userTier: Int?

        // Computed properties
        var translatedCityName: String? {
            servers.first?.translatedCity
        }

        public var displayName: String {
            translatedCityName ?? cityName
        }

        var isAnyServerConnected: Bool {
            servers.contains { $0.isCurrentlyConnected }
        }

        var isUsersTierTooLow: Bool {
            servers.allSatisfy(\.isUsersTierTooLow)
        }

        var underMaintenance: Bool {
            servers.allSatisfy(\.underMaintenance)
        }

        var alphaOfMainElements: Double {
            if underMaintenance {
                return 0.25
            }
            if isUsersTierTooLow {
                return 0.5
            }
            return 1.0
        }

        public var countryFlag: UIImage? {
            UIImage.flag(countryCode: countryCode)
        }

        public var countryName: String {
            LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
        }

        public var textInPlaceOfConnectIcon: String? {
            isUsersTierTooLow ? Localizable.upgrade : nil
        }

        public var connectIcon: UIImage? {
            if isUsersTierTooLow {
                Theme.Asset.vpnSubscriptionBadge.image
            } else if underMaintenance {
                IconProvider.wrench
            } else {
                IconProvider.powerOff
            }
        }

        var isConnected: Bool {
            servers.contains(where: \.isConnected)
        }

        var isConnecting: Bool {
            servers.contains(where: \.isConnecting)
        }

        var isCurrentlyConnected: Bool {
            isConnected || isConnecting
        }

        public var connectButtonColor: UIColor {
            if isUsersTierTooLow {
                return .clear
            }
            if underMaintenance {
                return .clear
            }
            return isCurrentlyConnected ? UIColor.interactionNorm() : UIColor.weakInteractionColor()
        }
    }

    public enum Action {
        case none
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .none:
                .none
            }
        }
    }
}
