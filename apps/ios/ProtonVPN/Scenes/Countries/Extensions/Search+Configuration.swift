//
//  Created on 02.03.2022.
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

import Foundation
import Search
import vpncore
import UIKit

extension Configuration {
    init() {
        self.init(colors: Colors(background: .backgroundColor(), text: .normalTextColor(), brand: .brandColor(), weakText: .weakTextColor()))
    }
}

extension CountryItemViewModel: CountryViewModel {
    func getServers() -> [ServerTier: [ServerViewModel]] {
        var data: [ServerTier: [ServerViewModel]] = [:]
        for tier in ServerTier.allCases {
            data[tier] = []
        }

        for (tier, servers) in serverViewModels {
            let serverTier: ServerTier
            switch tier {
            case CoreAppConstants.VpnTiers.free:
                serverTier = .free
            case CoreAppConstants.VpnTiers.plus:
                serverTier = .plus
            default:
                serverTier = .basic
            }
            data[serverTier]?.append(contentsOf: servers)
        }
        return data
    }

    var flag: UIImage? {
        return UIImage(named: countryCode.lowercased() + "-plain")
    }

    var connectButtonColor: UIColor {
        return isCurrentlyConnected ? UIColor.brandColor() : (underMaintenance ? UIColor.weakInteractionColor() : UIColor.secondaryBackgroundColor())
    }

    var textColor: UIColor {
        return UIColor.normalTextColor()
    }
}

extension ServerItemViewModel: ServerViewModel {
    var connectButtonColor: UIColor {
        return connectedUiState ? .brandColor() : (underMaintenance ? .weakInteractionColor() :  .secondaryBackgroundColor())
    }
}
