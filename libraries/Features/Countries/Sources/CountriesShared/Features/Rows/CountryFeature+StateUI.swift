//
//  Created on 27/02/2026 by Max Kupetskyi.
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

import Localization
import Strings
import SwiftUI
import Theme

public extension CountryFeature.State {
    var description: String {
        switch serverGroup.kind {
        case let .country(countryCode):
            LocalizationUtility.default.countryName(forCode: countryCode) ?? "Unavailable"
        case let .gateway(gatewayName):
            gatewayName
        case let .city(name, _), let .state(name, _):
            name
        }
    }

    var torAvailable: Bool {
        serverGroup.featureUnion.contains(.tor)
    }

    var p2pAvailable: Bool {
        serverGroup.featureUnion.contains(.p2p)
    }

    var isSmartAvailable: Bool {
        serverGroup.supportsSmartRouting
    }

    var streamingAvailable: Bool {
        !streamingServices.isEmpty
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

    var textInPlaceOfConnectIcon: String? {
        isUsersTierTooLow ? Localizable.upgrade : nil
    }

    var isSecureCoreCountry: Bool {
        serverGroup.featureIntersection.contains(.secureCore)
    }

    var flag: ImageAsset.Image? {
        switch serverGroup.kind {
        case let .country(countryCode):
            return ImageAsset.Image.flag(countryCode: countryCode)
        case .gateway:
            return Theme.Asset.Flags.gateway.image
        case .city, .state:
            assertionFailure("Unexpected grouping kind: \(serverGroup.kind)")
            return nil
        }
    }

    var connectIcon: Theme.ThemeIcon {
        if isUsersTierTooLow {
            Theme.Asset.vpnSubscriptionBadgeIcon
        } else if underMaintenance {
            Theme.Asset.Icons.wrench
        } else {
            Theme.Asset.Icons.powerOff
        }
    }

    var connectButtonColor: Color {
        if isUsersTierTooLow {
            return .clear
        }
        if underMaintenance {
            return .clear
        }
        return isCurrentlyConnected ? Color(.icon, .interactive) : Color(.icon, [.interactive, .weak])
    }
}
