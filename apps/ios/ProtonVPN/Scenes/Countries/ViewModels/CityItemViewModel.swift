//
//  Created on 16.03.2022.
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
import UIKit
import Search
import vpncore

final class CityItemViewModel: CityViewModel {
    let name: String

    let countryName: String

    let countryFlag: UIImage?

    var isUsersTierTooLow: Bool {
        return servers.allSatisfy({ $0.isUsersTierTooLow })
    }

    var underMaintenance: Bool {
        return servers.allSatisfy({ $0.underMaintenance })
    }

    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            return #imageLiteral(resourceName: "con-locked")
        } else if underMaintenance {
            return #imageLiteral(resourceName: "ic_maintenance")
        } else {
            return #imageLiteral(resourceName: "con-available")
        }
    }

    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? LocalizedString.upgrade : nil
    }

    var isCurrentlyConnected: Bool {
        return servers.contains(where: { $0.connectedUiState })
    }

    var connectButtonColor: UIColor {
        return isCurrentlyConnected ? UIColor.brandColor() : (underMaintenance ? UIColor.weakInteractionColor() : UIColor.secondaryBackgroundColor())
    }

    var server: ServerViewModel? {
        return servers.first
    }

    var connectionChanged: (() -> Void)?

    private let servers: [ServerItemViewModel]

    init(name: String, countryName: String, countryFlag: UIImage?, servers: [ServerItemViewModel]) {
        self.name = name
        self.countryName = countryName
        self.countryFlag = countryFlag
        self.servers = servers

        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: VpnGateway.connectionChanged, object: nil)
    }

    func updateTier() {
        servers.forEach {
            $0.updateTier()
        }
    }

    func connectAction() {
        server?.connectAction()
    }

    // MARK: - Private functions

    @objc private func stateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionChanged?()
        }
    }
}
