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

    private let alertService: AlertService
    private var vpnGateway: VpnGatewayProtocol?
    private let connectionStatusService: ConnectionStatusService

    let cityName: String

    let translatedCityName: String?

    var countryName: String {
        return LocalizationUtility.default.countryName(forCode: countryModel.countryCode) ?? ""
    }

    var countryFlag: UIImage? {
        return UIImage.flag(countryCode: countryModel.countryCode)
    }

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

    var isConnected: Bool {
        return servers.contains(where: { $0.isConnected })
    }

    var isConnecting: Bool {
        return servers.contains(where: { $0.isConnecting })
    }

    var isCurrentlyConnected: Bool {
        return isConnected || isConnecting
    }

    var connectButtonColor: UIColor {
        return isCurrentlyConnected ? UIColor.brandColor() : (underMaintenance ? UIColor.weakInteractionColor() : UIColor.secondaryBackgroundColor())
    }

    var connectionChanged: (() -> Void)?

    private let servers: [ServerItemViewModel]
    private let countryModel: CountryModel

    init(cityName: String, translatedCityName: String?, countryModel: CountryModel, servers: [ServerItemViewModel], alertService: AlertService, vpnGateway: VpnGatewayProtocol?, connectionStatusService: ConnectionStatusService) {
        self.cityName = cityName
        self.translatedCityName = translatedCityName
        self.countryModel = countryModel
        self.servers = servers
        self.alertService = alertService
        self.vpnGateway = vpnGateway
        self.connectionStatusService = connectionStatusService

        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: VpnGateway.connectionChanged, object: nil)
    }

    func updateTier() {
        servers.forEach {
            $0.updateTier()
        }
    }

    func connectAction() {
        guard let vpnGateway = vpnGateway else {
            return
        }

        updateTier()

        log.debug("Connect requested by clicking on Country item", category: .connectionConnect, event: .trigger)

        if isUsersTierTooLow {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            alertService.push(alert: AllCountriesUpsellAlert())
        } else if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert(cityName: countryName))
        } else if isConnected {
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            log.debug("Will connect to city: \(cityName) in country: \(countryName)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(country: countryModel.countryCode, city: cityName)
            connectionStatusService.presentStatusViewController()
        }
    }

    // MARK: - Private functions

    @objc private func stateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionChanged?()
        }
    }
}
